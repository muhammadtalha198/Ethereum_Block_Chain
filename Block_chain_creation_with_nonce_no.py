#Week 2 Task 
#Create a block chain with generating a nonce where the target value match

#import the hashlib library to create the hash of any data.
import hashlib

#This colud be the maximum nonce you are gona put to find the right nonce number which-
#-matches the target value
maximum_nonce_no = 100000000000

#create your Block Class
class Block:
    def __init__(self,block_number, transactions, previous_hash, difficulty_level):
        self.block_number = block_number
        self.transactions = transactions
        self.previous_hash = previous_hash
        self.difficulty_level = difficulty_level
        
    
    #This method will generate the hash of the given string
    def HashGenerator(self,given_string):
        return hashlib.sha256(given_string.encode("ascii")).hexdigest()

    #This method give the value of the nonce at which the nonce -
    #-value matches the target value
    def StartMining(self):

        #the target value will be like how many before-zeros we need in our hash-value
        target_value = '0'*self.difficulty_level
        
        for nonce in range(maximum_nonce_no):
            
            #create a string of all the values to create a hash
            given_string = str(self.block_number) + self.transactions + self.previous_hash + str(nonce)
           
           #call the hash-generator method to create the hash of the string.
            new_hash = self.HashGenerator(given_string) 
           
           #startswith method is use to check wether the Main string start fronm the given value
           # -in the paranthasis 
            if new_hash.startswith(target_value):
                #print(f"Yay! Successfully match the target value at this nonce no: {nonce}")
                #print(new_hash)
               
                #return the block hash-value and the nonce-value on which
                # -the value match the targetvalue.
                return new_hash,nonce 

        raise BaseException(f"Couldn't find correct hash after trying {maximum_nonce_no} times")
#create a main function 
if __name__=='__main__':
    
    #the no of transcations
    transactions1='''
    Dhaval->Bhavin->20,
    Mando->Cara->45
    '''
    transactions2='''
    Asad->bilal->20,
    Moni->Cara->45
    '''
    transactions3='''
    tom->Bhavin->20,
    sara->Cara->45
    '''
    #The difficulty leve will like how many zeros we want in starting our hash-number
    difficulty_level=4 
    
    #create our First-block
    initial_block= Block(1,transactions1,'6be9a2b8321c6ec7', difficulty_level)
    print ("The hash of the block is: " + initial_block.StartMining()[0])
    print ("The nonce value where it match the target: " + str(initial_block.StartMining()[1]))
    
    second_block = Block(2,transactions2,initial_block.StartMining()[0], difficulty_level)
    print ("The hash of the block is: " + second_block.StartMining()[0])
    print ("The nonce value where it match the target: " + str(second_block.StartMining()[1]))

    third_block = Block(3,transactions3,second_block.StartMining()[0], difficulty_level)
    print ("The hash of the block is: " + second_block.StartMining()[0])
    print ("The nonce value where it match the target: " + str(second_block.StartMining()[1]))