pragma solidity ^0.5.9;


contract KYC{
    
    address  admin;
    
  
    struct Customer{
        bytes32 name;
        bytes32 data_hash;
        bool kycStatus;
        uint8 upvote;
        uint8 downvote;
        address bank;
    }
    
    struct Bank{
        bytes32 name;
        address ethAddress;
        bytes regNumber;
        uint8 reports;
        uint256 kyc_count;
        bool kycPermission;
        
    }
    
    struct KycRequest{
        bytes32 name;
        bytes32 data_hash;
        address bank;
        bool status;
    }
    
    constructor() public{
        
        //contract deployer will be the admin of KYC network
        admin = msg.sender;
    }
    
    mapping(bytes32 => KycRequest) KycRequests;
    bytes32[] customersData;
    
    mapping(bytes32 => Customer) customers;
    bytes32[] customerNames;
    
    mapping( address => Bank) banks;
    address[] bankAddresses;
    
    mapping( bytes32 => mapping(address => uint256)) upVotes;
    
    mapping( bytes32 => mapping(address => uint256)) downvotes;
    
    /*
    Method to add a kyc request
    @param _name - customer username
    @param _customerData - customer's kyc data
    @return - 1 for success
    */
    function addKycRequest(bytes32 _name, bytes32 _customerData) public checkBankEligibility returns(uint8){
        require(KycRequests[_customerData].bank == address(0), "This user already has a KYC request with same data in process.");
        
        //add kyc request in request map
        KycRequests[_customerData].name = _name;
        KycRequests[_customerData].data_hash = _customerData ;
        KycRequests[_customerData].bank = msg.sender;
        
        //add kyc request in request list
        customersData.push(_customerData);
        
        //increment bank kyc request counter
        banks[msg.sender].kyc_count++;
        
        return 1;
    }
    
    /*
    Method to add a customer
    @param _name - customer username
    @param _customerData - customer's kyc data
    @return - 1 for success
    */
    function addCustomer(bytes32 _name, bytes32 _customerData) public checkBankEligibility returns(uint8){
        require(customers[_name].bank == address(0), "This customer is already present, please call modifyCustomer to edit the customer data");
        require(KycRequests[_customerData].bank != address(0), "Customer does not have kyc request. Kindly  raise a kyc request.");
       
        //add customer in customers map
        customers[_name].name = _name;
        customers[_name].data_hash = _customerData;
        customers[_name].bank = msg.sender;
        customers[_name].upvote = 0;
        
        //add customers in customers list
        customerNames.push(_name);
        
        return 1;
    }
    
    /*
    Method to remove a kyc request
    @param _username - customer name
    @return - 1 for success, 0 for failure
    */
    function removeKycRequest(bytes32 _username) public checkBankExists returns(uint8){
        require(banks[msg.sender].ethAddress != address(0), "Your Bank is not present in network. Contact Admin to add.");
        
        
        for(uint256 i =0; i< customersData.length; ++i){
            
            //find kyc request from user name
            if(bytesEquals(KycRequests[customersData[i]].name, _username)){
                
                //delete kyc request from map
                delete KycRequests[customersData[i]];
                
                //delete kyc request record from list
                for(uint256 j=i+1; j< customersData.length ; ++j){
                    customersData[j-1] = customersData[j]; 
                }
                
                //decrement list length
                customersData.length--;
                return 1;
            }
        }
        return 0;
    }
    
    /*
    Method to remove customer from global list
    @param _username - customer username
    @return - 1 for success, 0 for failure
    */
    function removeCustomer(bytes32 _username) public checkBankEligibility returns(uint8){
        require( customers[_username].bank != address(0), "Customer is not present in network");
        
        for(uint256 i=0; i<customerNames.length; ++i){
            if(bytesEquals( customerNames[i], _username)){
                
                //check bank is the owner of customer record
                require(customers[_username].bank == msg.sender, "Only the bank which added the customer can remove customer.");
                
                
                //delete customer kyc request
                removeKycRequest(_username);
                
                
                //delete customer from mapping
                delete customers[_username];
                
                //delete customer name from list
                for(uint256 j = i+1; j< customerNames.length; ++j){
                    customerNames[j-1] = customerNames[j];
                }
                customerNames.length--;
                
                return 1;
            }
        }
        return 0;
    }
    
    /*
    Method to modify a customer's kyc data
    @param _username - customer name
    @param _customerData - customer's kyc data
    @return - 1 for success
    */
    function modifyCustomer( bytes32 _username, bytes32 _customerData) public checkBankEligibility returns(uint8){
        require( customers[_username].bank != address(0), "Customer is not present in network");
        
        //update customer data hash and set upvote,downvote to zero
        customers[_username].data_hash = _customerData; 
        customers[_username].upvote = 0;
        customers[_username].downvote = 0;
        customers[_username].kycStatus = false;
        
        //delete  kyc request of Customer
        removeKycRequest(_username);
        
        return 1;
    }
    
    /*
    Method to view customer details
    @param _username - username
    @return - customer details in following order (name, kyc data, upvote, downvote and bank associated)
    */
    function viewCustomer(bytes32 _username) public view checkBankExists returns(bytes32, bytes32,  uint8, uint8, address){
        require( customers[_username].bank != address(0), "Customer is not present in network");
        
        //return customer details (name, kyc data, upvote, downvote and bank associated)
        return (customers[_username].name, customers[_username].data_hash, customers[_username].upvote,customers[_username].downvote, customers[_username].bank );
    }
    
    
    /*
    Method to upvote a customer
    @param _username - customer name
    @return - 1 for success
    */
    function upVote(bytes32 _username) public checkBankEligibility returns(uint8){
        
        require( customers[_username].bank != address(0), "Customer is not present in network");
        require( upVotes[_username][msg.sender] == 0, "Bank already upvoted the customer");
        
        //increment upvote counter
        customers[_username].upvote++;
        upVotes[_username][msg.sender] = now;
        
        //enable kyc status,
        //if network contains atleast 5 bank and
        //upvotes are greater than downvotes and 
        //upvote > 1/3rd of number of bank 
        //downvote should be lesser than 1/3rd of number of bank
        if(bankAddresses.length >= 5 && 
        customers[_username].upvote > (bankAddresses.length/3) &&
        customers[_username].upvote > customers[_username].downvote && 
        customers[_username].downvote < (bankAddresses.length/3)){  //condition to stop toggling of kyc status, when upvote is done after kyc status made false due to downvotes
            
            //enable customer kyc status
            customers[_username].kycStatus = true;
            
            //enable  customer's kyc request status
            assert(KycRequests[customers[_username].data_hash].bank != address(0));
            
            ////enable kyc status in customer's kyc request
            KycRequests[customers[_username].data_hash].status = true;
            
        }
        return 1;
      
    }
    
    /*
    Method to downvote a customer
    @param _username - customer name
    @return - 1 for success
    */
    function downvote(bytes32 _username) public checkBankEligibility returns(uint8){
        require( customers[_username].bank != address(0), "Customer is not present in network");
        require( downvotes[_username][msg.sender] == 0, "Bank already downvoted the customer");
        
        //increment customer's downvote counter
        customers[_username].downvote++;
        
        //revoke kyc status of customer,
        //if customer is downvoted by 1/3rd of banks and 
        //network contains atleast 5 bank
        if(bankAddresses.length >= 5 && customers[_username].downvote >= (bankAddresses.length/3)){
            
            customers[_username].kycStatus = false;
        }
        downvotes[_username][msg.sender] = now;
        return 1;
    }
    
    /*
    Method to compare two bytes32 data
    @param _name - customer name
    @param _customerData - customer's kyc data
    @return - true if matches, otherwise false 
    */
    function bytesEquals(bytes32 a, bytes32 b) internal pure returns(bool){
        
        //compare length
        if(a.length != b.length)
            return false;
            
        //compare each byte
        for(uint i=0;i< a.length; ++i){
            if(a[i] != b[i])
                return false;
        }
        return true;
    }
    
    /*
    modifier to check bank eligibility 
    */
    modifier checkBankEligibility(){
        require(banks[msg.sender].ethAddress != address(0), "Your Bank is not present in network. Contact Admin to add.");
        require(banks[msg.sender].kycPermission, "Bank has been marked faulty. Contact Admin!");
       
        _;
    }
    
    /*
    checks bank is exisitng in kyc network
    */
    modifier checkBankExists(){
        require(banks[msg.sender].ethAddress != address(0), "Your Bank is not present in network.");
        _;
    }
    
    /*
    Gets number of reports on a bank
    @param bank - bank address
    @return - an integer
    */
    function getBankReports(address bank) public view checkBankExists returns(int256){
        require(banks[bank].ethAddress != address(0), "Defined Bank is not present in network.");
        return banks[bank].reports;
    } 
    
    /*
    Gets customer status
    @param _username - customer name
    @return - true if customer has verified kyc, else false
    */
    function getCustomerStatus( bytes32 _username) public view checkBankExists returns(bool){
        require( customers[_username].bank != address(0), "Customer is not present in network");
        return customers[_username].kycStatus;
    }
    
    /*
    Gets bank details
    @param bank - bank address
    @return - bank details in order as follows (name, address, registration number, number of reports, number of kyc requests raised, kyc kycPermission)
    */
    function viewBankDetails( address bank) public view checkBankExists returns(  bytes32 , address, bytes memory, uint8, uint256, bool){
        require(banks[bank].ethAddress != address(0), "Defined Bank is not present in network.");
        return (banks[bank].name, banks[bank].ethAddress, banks[bank].regNumber, banks[bank].reports, banks[bank].kyc_count, banks[bank].kycPermission);
    }
    
    /*
    Report a bank
    @param bank - bank address
    */
    function reportBank(address bank) public checkBankEligibility {
        require(banks[bank].ethAddress != address(0), "Defined Bank is not present in network.");
        
        //increment bank's report counter
        banks[bank].reports++ ;
        
        //disable bank's kyc permission if,
        //no. of bank is greater than 5 and
        //no. reports is greater than 1/3rd of no. of bank
        if( banks[bank].kycPermission &&
        bankAddresses.length >=5  && 
        banks[bank].reports > (bankAddresses.length/3)){        //no. reports is greater than 1/3rd of no. of bank
            banks[bank].kycPermission = false;
        }
        
    }
    
    /*
    modifier to check msg sender is the admin
    @param message - error message to be sent if transaction fails
    */
    modifier isAdmin(){
        require( msg.sender == admin, "Only Admin can perform the operation");
        _;
    }
    
    /*
    Method to add a bank, only admin can perform this operation
    @param name - bank name
    @param ethAddress - bank address
    @param regNumber - registration number for bank
    @return - 1 for success
    */
    function addBank(bytes32 name, address ethAddress, bytes memory regNumber)public isAdmin()
    {
        require(banks[ethAddress].ethAddress == address(0), "Bank is already present in network");
        
        //add bank in map
        banks[ethAddress].name = name;
        banks[ethAddress].ethAddress = ethAddress;
        banks[ethAddress].regNumber = regNumber;
        banks[ethAddress].reports = 0;
        banks[ethAddress].kycPermission = true;
        banks[ethAddress].kyc_count = 0;
        
        //add bank address in list
        bankAddresses.push(ethAddress);
    }
    
    /*
    Method to modify the bank kyc permission,  only admin can perform this operation
    @param ethAddress - bank address
    */
    function modifyBankKyc(address ethAddress) public isAdmin(){
        require(banks[ethAddress].ethAddress != address(0), "Bank is not present in network");
        banks[ethAddress].kycPermission = false;
    }
    
    
    /*
    Method to remove a bank from network,  only admin can perform this operation
    @param ethAddress - bank address
    */
    function removeBank(address ethAddress) public isAdmin(){
        require(banks[ethAddress].ethAddress != address(0), "Defined Bank is not present in network");
        
        //delete bank
        delete banks[ethAddress];
        
        for(uint256 i=0; i< bankAddresses.length; ++i){
            
            //find bank in list
            if(bankAddresses[i] ==  ethAddress){
                for(uint256 j =i+1; j<bankAddresses.length; ++j){
                    
                    //delete bank
                    bankAddresses[j-1] = bankAddresses[j];
                }
                
                //decrement number of bank
                bankAddresses.length--;
                return;
            }
        }
    }
    
}