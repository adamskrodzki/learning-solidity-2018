pragma solidity ^0.4.24;


/*
    Lottery is safe under the assumption that miners do not interfere,
    no smart contract can hack me (If You can prove me otherwise :D )
*/

/*Solidity is Object Oriented Let's use it that way*/

contract SingleLottery{
    mapping(address => uint8) public participated;
    mapping(uint8 => uint256) public choiceCount;
    uint256 public sumCollected ;
    uint256 public constant WAIT_BLOCKS_LIMIT = 3 ;
    uint256 public constant REGISTERING_PARTICIPANTS = 1;
    uint256 public constant REGISTERING_FINISHED = 2;
    uint256 public constant WAITING_FOR_RANDOMNESS = 3;
    uint256 public constant SOLVING_LOTERRY = 4;
    uint256 public constant LOTTERY_SOLVED = 5;
    uint256 public constant REGISTRATION_DURATION = 1 days;
    uint256 public startTime; 
    uint256 public waitingStartBlockNumber;
    uint8 public winningNumber;
    uint256 public payoutSum; 
    bool public lotterySolved;
    LotteryCompany public owner;
    
    modifier onlyOwner{ //here parent contract
        require (msg.sender == address(owner));
        _;
    }
    
    constructor() public{
        owner = LotteryCompany(msg.sender);
        startTime = now;
        NewLottery(block.number);
    }
    
    
    function play(uint8 choice,address sender) public payable onlyOwner returns(uint256){
        require(choice>0 && choice<101);
        if(getStage(block.number)==REGISTERING_PARTICIPANTS){
            processAddingUser(sender,choice);
        }
        else{ // this else is crutial so we never enter two stages in same call
            if(getStage(block.number)==REGISTERING_FINISHED){
                waitingStartBlockNumber = block.number;
                emit ClosingList(waitingStartBlockNumber);
                sender.transfer(msg.value);// send whatever funds has been sent user have not participated in lottery because it was to late
            }
            else{
                if(getStage(block.number)==WAITING_FOR_RANDOMNESS){
                        
                        revert("To little time passed, wait at least WAIT_BLOCKS_LIMIT ");
                }
                else{
                    if(getStage(block.number)==SOLVING_LOTERRY){
                        processSolvingLottery();
                        sender.transfer(msg.value);// send whatever funds has been sent user have not participated in lottery because it was to late
                    }
                }
            }
        }
        return getStage(block.number); //returns stage after processing 
    }
    
    
    function supplyFunds() payable onlyOwner public{
        
    }
    
    function withdraw(address sender) onlyOwner public {
        if(getStage(block.number)==SOLVING_LOTERRY){
            processSolvingLottery();
        }
        if((winningNumber>0) && (participated[sender]==winningNumber)){
            participated[sender]=0;
            sender.transfer(payoutSum);
        }
    }
    
        
    function getStage(uint256 blockNum) public view returns(uint256) {
        if(now-startTime<REGISTRATION_DURATION){
            return REGISTERING_PARTICIPANTS;
        }
        else{
            if(waitingStartBlockNumber==0 //start waiting block has been never set
                || blockNum-waitingStartBlockNumber>=256 //start waiting block has been set long time ago
                ){
                return REGISTERING_FINISHED;
            }
            else
            {
                if(blockNum-waitingStartBlockNumber<WAIT_BLOCKS_LIMIT){
                    return WAITING_FOR_RANDOMNESS;
                }
                else{
                    if(lotterySolved == true){
                        return LOTTERY_SOLVED;
                    }
                    else{
                        return SOLVING_LOTERRY;
                    }
                }
            }
        }
    }
    
    function processAddingUser(address sender,uint8 choice)  private{
        require(msg.value==100 finney,"Must send 0.1 ether");
        require(participated[sender]==0,"One address can pericipate only once");
        participated[sender] = choice;
        choiceCount[choice]= choiceCount[choice]+1;
        emit UserRegistered(sender,choice);
    }
    
    function processSolvingLottery() private{
        uint256 luckyNumber = uint256(blockhash(waitingStartBlockNumber+WAIT_BLOCKS_LIMIT));
        luckyNumber = (luckyNumber % 100)+1;
        winningNumber = uint8(luckyNumber);
        lotterySolved = true;
        owner.supplyFunds.value(address(this).balance/2)();//half for next lotteries
        payoutSum = address(this).balance/choiceCount[winningNumber];
    }
    
    event NewLottery(uint256 blockNum);
    event ClosingList(uint256 blockNum);
    event UserRegistered(address adr,uint8 choice);
    event UseRewarded(address adr,uint256 blockNum);
}
contract LotteryCompany{

    
    //assumes that lotteries never overlap
    SingleLottery public currentLottery;
    mapping(address => address) lastPlayed;
    uint256 public constant LOTTERY_SOLVED = 5; // same as in SingleLottery
    
    address public owner;
    
    modifier onlyOwner{ //here parent contract
        require (msg.sender == address(owner));
        _;
    }
    
    constructor() public{
        owner = LotteryCompany(msg.sender);
        currentLottery = new SingleLottery();
    }
    
    function supplyFunds() payable public{
        
    }
    
    function play(uint8 choice) public payable {
        withdraw(); // next play cause withdraw of previous game
        if(msg.value>0){
            if(currentLottery.play.value(msg.value)(choice,msg.sender)==LOTTERY_SOLVED){
                //time to create next lottery 
                currentLottery = new SingleLottery();
                currentLottery.supplyFunds.value(address(this).balance)(); // send full balance to next lottery
                currentLottery.play.value(msg.value)(choice,msg.sender); //play new lottery 
            }
            lastPlayed[msg.sender] = address(currentLottery);
        }
        
    }
    
    function withdraw() public {
        if(lastPlayed[msg.sender]!=address(0)){ // should never throw since is called unconditionally in play
            SingleLottery(lastPlayed[msg.sender]).withdraw(msg.sender);
        }
    }
    
    event ClosingList(uint256 blockNum);
    event UserRegistered(address adr);
    event UseRewarded(address adr,uint256 blockNum);
}
