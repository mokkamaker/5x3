// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./accesscontrol/ConsumerRole.sol";
import "./accesscontrol/DistributorRole.sol";
import "./accesscontrol/FarmerRole.sol";
import "./accesscontrol/RetailerRole.sol";

contract SupplyChain is Ownable, ConsumerRole, FarmerRole, DistributorRole, RetailerRole {

    // universal product code, generated by the farmer, goes on the package, can be verified by the consumer
    uint upc;

    // stock keeping unit
    uint sku;

     // Define enum 'State' with the following values:
    enum State { 
        Harvested,  // 0
        Processed,  // 1
        Packed,     // 2
        ForSale,    // 3
        Sold,       // 4
        Shipped,    // 5
        Received,   // 6
        Purchased   // 7
    }

    State constant defaultState = State.Harvested;

    struct Item {
        uint sku; 
        uint upc; 
        address payable ownerID; // address of the current owner 
        address payable farmerID; // address of the farmer
        string farmName;
        string farmInformation; 
        string farmLatitude;
        string farmLongitude;
        uint productID; // a product id, might be a combination of sku and upc
        string productNotes;
        uint productPrice;
        State itemState; 
        address payable distributorID; // address of the distributor
        address payable retailerID; // address of the retailer
        address payable consumerID; // address of the consumer
    }

    //map the UPC to an Item
    mapping (uint => Item) items;

    // Define a public mapping 'itemsHistory' that maps the UPC to an array of TxHash, 
    // that track its journey through the supply chain -- to be sent from DApp.
    mapping (uint => string[]) itemsHistory;

    // Define 8 events with the same 8 state values and accept 'upc' as input argument
    event Harvested(uint upc);
    event Processed(uint upc);
    event Packed(uint upc);
    event ForSale(uint upc);
    event Sold(uint upc);
    event Shipped(uint upc);
    event Received(uint upc);
    event Purchased(uint upc);

    modifier verifyCaller(address _address) {
        require(msg.sender == _address);
        _;
    }

    modifier paidEnough(uint _price) {
        require(msg.value >= _price);
        _;
    }
    
    modifier checkValue(uint _upc) {
        _;
        uint _price = items[_upc].productPrice;
        uint amountToReturn = msg.value - _price;
        items[_upc].consumerID.transfer(amountToReturn);
    }

    modifier harvested(uint _upc) {
        require(items[_upc].itemState == State.Harvested);
        _;
    }

    modifier processed(uint _upc) {
        require(items[_upc].itemState == State.Processed);
        _;
    }

    modifier packed(uint _upc) {
        require(items[_upc].itemState == State.Packed);
        _;
    }

    modifier forSale(uint _upc) {
        require(items[_upc].itemState == State.ForSale);
        _;
    }

    modifier sold(uint _upc) {
        require(items[_upc].itemState == State.Sold);
        _;
    }
    
    modifier shipped(uint _upc) {
        require(items[_upc].itemState == State.Shipped);
        _;
    }

    modifier received(uint _upc) {
        require(items[_upc].itemState == State.Received);
        _;
    }

    modifier purchased(uint _upc) {
        require(items[_upc].itemState == State.Purchased);
        _;
    }

    // In the constructor set 'sku' to 1
    // and set 'upc' to 1
    constructor() payable {
        sku = 1;
        upc = 1;
    }

    function harvestItem(uint _upc, address payable _farmerID, string memory _farmName, string memory _farmInformation, string memory _farmLatitude, string memory _farmLongitude, string memory _productNotes) public 
    {
        items[_upc] = Item ({
            sku: sku,
            upc: _upc,
            ownerID: _farmerID,
            farmerID: _farmerID,
            farmName: _farmName,
            farmInformation: _farmInformation,
            farmLongitude: _farmLongitude,
            farmLatitude: _farmLatitude,
            productID: sku + _upc,
            productNotes: _productNotes,
            productPrice: 0,
            itemState: State.Harvested,
            distributorID: payable(address(0)),
            retailerID: payable(address(0)),
            consumerID: payable(address(0))
        });
        
        sku = sku + 1;

        emit Harvested(_upc);
    }

    function processItem(uint _upc) public harvested(_upc) verifyCaller(items[_upc].farmerID)
    {
        items[_upc].itemState = State.Processed;
        emit Processed(_upc);
    }

    function packItem(uint _upc) public processed(_upc) verifyCaller(items[_upc].farmerID)
    {
        items[_upc].itemState = State.Packed;
        emit Packed(_upc);
    }

    function sellItem(uint _upc, uint _price) public packed(_upc) verifyCaller(items[_upc].farmerID)
    {
        items[_upc].itemState = State.ForSale;
        items[_upc].productPrice = _price;

        emit ForSale(_upc);
    }   

    function buyItem(uint _upc) onlyDistributor public payable forSale(_upc) paidEnough(items[_upc].productPrice) checkValue(_upc)
    {
        items[_upc].ownerID = payable(msg.sender);
        items[_upc].distributorID = payable(msg.sender);
        items[_upc].itemState = State.Sold;

        items[_upc].farmerID.transfer(items[_upc].productPrice);

        emit Sold(_upc);
    }

    function shipItem(uint _upc) public sold(_upc) verifyCaller(items[_upc].distributorID)
    {
        items[_upc].itemState = State.Shipped;
        emit Shipped(_upc);
    }

    function receiverItem(uint _upc) onlyRetailer public shipped(_upc)
    {
        items[_upc].ownerID = payable(msg.sender);
        items[_upc].retailerID = payable(msg.sender);
        items[_upc].itemState = State.Received;

        emit Received(_upc);
    }

    function purchaseItem(uint _upc) onlyConsumer public received(_upc) 
    {
        items[_upc].ownerID = payable(msg.sender);
        items[_upc].consumerID = payable(msg.sender);
        items[_upc].itemState = State.Purchased;

        emit Purchased(_upc);

    }

    function fetchItemBufferOne(uint _upc) public view returns 
    (
    uint itemSKU,
    uint itemUPC,
    address ownerID,
    address farmerID,
    string memory farmName,
    string memory farmInformation,
    string memory farmLatitude,
    string memory farmLongitude
    ) 
    {
        // Assign values to the 8 parameters
        itemSKU = items[_upc].sku;
        itemUPC = items[_upc].upc;
        ownerID = items[_upc].ownerID;
        farmerID = items[_upc].farmerID;
        farmName = items[_upc].farmName;
        farmInformation = items[_upc].farmInformation;
        farmLatitude = items[_upc].farmLatitude;
        farmLongitude = items[_upc].farmLongitude;      

        return 
        (
        itemSKU,
        itemUPC,
        ownerID,
        farmerID,
        farmName,
        farmInformation,
        farmLatitude,
        farmLongitude
        );
    }

   function fetchItemBufferTwo(uint _upc) public view returns 
    (
    uint itemSKU,
    uint itemUPC,
    uint productID,
    string memory productNotes,
    uint productPrice,
    uint itemState,
    address distributorID,
    address retailerID,
    address consumerID
    ) 
    {
        // Assign values to the 9 parameters
        itemSKU = items[_upc].sku;
        itemUPC = items[_upc].upc;
        productID = items[_upc].productID;
        productNotes = items[_upc].productNotes;
        productPrice = items[_upc].productPrice;
        //convert to numeric value
        itemState =  uint(items[_upc].itemState);
        distributorID = items[_upc].distributorID;
        retailerID = items[_upc].retailerID;
        consumerID = items[_upc].consumerID;
        
    return 
    (
    itemSKU,
    itemUPC,
    productID,
    productNotes,
    productPrice,
    itemState,
    distributorID,
    retailerID,
    consumerID
    );
    }
}