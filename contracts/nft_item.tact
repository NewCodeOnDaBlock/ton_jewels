import "@stdlib/deploy";
import "@stdlib/ownable";
import "./messages.tact";

contract NftItem with Deployable, Ownable {
    const minTonsForStorage: Int = ton("0.03");
    const gasFee: Int = ton("0.05");

    collection_address: Address;
    item_index: Int; 
    owner: Address;
    individual_content: Cell;
    is_initialized: Bool;

    init(
        collection_address: Address, 
        item_index: Int,
        owner: Address,
        individual_content: Cell
    ){
        self.collection_address = collection_address;
        self.item_index = item_index;
        self.owner = collection_address;
        self.individual_content = individual_content;
        self.is_initialized = false;
    }

    fun mint(new_owner: Address) {
        self.requireOwner();
        self.owner = new_owner;
    }

    receive(msg: Transfer){
        let ctx: Context = context();
        
        let msgValue: Int = ctx.value; // Check the gasFee for storage
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        msgValue = msgValue - (storageFee + self.gasFee);

        require(ctx.sender == self.owner, "not owner");
        if (self.is_initialized == false) {  // Initial Transfer, aka Minting.
            require(msg.custom_payload != null, "custum_payload is not exist");
            
            self.is_initialized = true;
            self.owner = msg.new_owner;
            self.individual_content = msg.custom_payload!!;
            send(SendParameters{
                to: msg.response_destination,
                value: msgValue,
                mode:  SendIgnoreErrors,
                body: Excesses {
                        query_id: msg.query_id
                    }.toCell()
                });
        } else {
            self.owner = msg.new_owner; // change current owner to the new_owner
            if (msg.forward_amount > 0) {
                send(SendParameters{
                    to: msg.new_owner,
                    value: msg.forward_amount,
                    mode: SendIgnoreErrors, 
                    bounce: false,
                    body: OwnershipAssigned{
                        query_id: msg.query_id,
                        prev_owner: ctx.sender,
                        forward_payload: msg.forward_payload
                    }.toCell()
                }); 
            }
            msgValue = msgValue - ctx.readForwardFee(); 
            if (msg.response_destination != null) { 
                send(SendParameters{ 
                    to: msg.response_destination,
                    value: msgValue - msg.forward_amount,
                    mode: SendPayGasSeparately,
                    body: Excesses { query_id: msg.query_id }.toCell() // 0xd53276db
                });
            }
        }
    }
    
    receive(msg: GetStaticData){ 
        let ctx: Context = context();

        send(SendParameters {
            to: ctx.sender,
            value: 0,
            mode: 64,  
            bounce: true,
            body: ReportStaticData{
                query_id: msg.query_id,
                index_id: self.item_index,
                collection: self.owner
            }.toCell()
        });
    }

    // --------- Get Function  --------- //
    get fun get_nft_data(): GetNftData {

        let b: StringBuilder = beginString();
        let collectionData: String = self.individual_content.asSlice().asString();
        b.append(collectionData);
        b.append(self.item_index.toString());

        return GetNftData {
            is_initialized: self.is_initialized, 
            index: self.item_index, 
            collection_address: self.collection_address, 
            owner_address: self.owner,
            individual_content: b.toCell()
        };
    }
}
