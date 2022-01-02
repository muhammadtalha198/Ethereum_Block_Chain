#Creata a simple block-chain in python.
import hashlib;

class Block:
   #Make a constructor
    def __init__ (self, previous_block_hash, transaction_list):
        self.previous_block_hash = previous_block_hash
        self.transaction_list = transaction_list

        #Construct a data string.
        self.block_data = "\n".join(transaction_list) + "\n" + previous_block_hash
        
        #This is how we calculate the hash 
        # # we have to encode it otherwise it wont work
        self.block_hash = hashlib.sha256(self.block_data.encode()).hexdigest()
        

#Now write some transactions
t1 = "Ana sends 34.4 coin to mike"
t2 = "bob sends 23 coin to ana"
t3 = "Ana sends 2.3 coin to maham"
t4 = "taha sends 4.2 coin to mike"
t5 = "Ana sends 3.7 coin to waleed"
t6 = "adeel sends 23.1 coin to mike"

#Now We have to creata a initial block
#just passing a simple message and our transactions.
#our initial string will be previous_block_hash
initial_block = Block("Genesis Block", [t1,t2])

#Now print the block data or hash
print(initial_block.block_data)
print(initial_block.block_hash)

#Now create the second block
second_block = Block(initial_block.block_hash,[t3,t4])

#Now print the block data or hash
print(second_block.block_data)
print(second_block.block_hash)