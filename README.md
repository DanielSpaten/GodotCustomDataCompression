In the following i'll present you two scripts, which allow you to create custom data-compression for reducing the data in your save-files or multiplayer-rpc's.

# Whats the idea?
The idea is to use the PackedByteArray. The scripts use every single bit inside this array to reduce the data to the smallest amount possible. This can be more efficient then ```var_to_bytes()```/```bytes_to_var()```, **IF** you know what kind of data you have.

e.g.:
A boolean will use 8 Bytes when converted with ```var_to_bytes()```, which seems crazy. Imagine if you want to store/send 8 booleans. The common way (```var_to_bytes```) will convert them to 64Bytes, while my solution will only need 1 Byte.

# How to use it?
## 1. Compress data
First you have to write your data. For this you will use the "BitWriter":
```
var bit_writer = BitWriter.new()
```
Then you can write data to it:
```
var bool_array = [true, false, true, false, true, false, true, false]
for boolean in bool_array:
	bit_writer.write_bool_flag(boolean)
```
After entering all the data you can request the PackedByteArray and send it(This will also reset the bit-writer, so you can resuse it for new data):
```
var data = bit_writer.get_byte_array()
target_node.recieve_data.rpc(data)
```
## 2. Decompress data
To decompress your data you need a BitReader and assign it the PackedByteArray:
```
var bit_reader = BitReader.new()

func recieve_data(byte_array: PackedByteArray):
	bit_reader.set_byte_array(byte_array)
```
Then you can read the data in the same order you wrote it:
```
var result_array = []
for i in 8:
	result_array.append(bit_reader.read_bool_flag())
```
# Can you write other things than bools?
Yes you can. I added the options to write integers of custom length(which also allows data-structures like Vectors):
```
bit_writer.write_int(integer_to_write, num_bits_to_write)
# ...
var integer = bit_reader.read_int(num_bits_to_read)
```
Note: This integer will be unsigned. Theres also an option to write a signed integer (write_signed_int)
# Add your own compression
Just use the write_bit-/write_bool-method to create your own custom compression. All bits of the PackedByteArray will be used automatically, guaranteeing the maximum compression possible.

# Should you use it?
This depends:
These scripts are useful **If**:
- You have large amount of data you want to send/store
- You have knowledge of your data (for example: you know your integers only need 10 Bits instead of the normal 64 bits)

If these cases dont apply, you probably dont need this.

# Conclusion
This is my first real contribution to the Godot-Ecosystem. I really enjoy this community and hope this can be useful somehow.

I would love to hear your feedback/improvements.

HerrSpaten
