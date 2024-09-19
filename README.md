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

# Here are the scripts:
## BitWriter
```
class_name BitWriter extends RefCounted

## This class writes Bits to a [PackedByteArray]
##
## Its supposed to be used in conjunction with the [BitReader],
## which allows for custom data compression

## The reset position of the bit-pointer
const POINTER_RESET: int = 7

## Caches the written bits
var _data: PackedInt32Array = []

## The current byte, that the Writer is writing to
var _byte: int
## The pointer inside of the currently used byte
var _bit_pointer: int = POINTER_RESET:
	set(value):
		if value < 0:
			_write_to_new_byte()
		else:
			_bit_pointer = value

## saves the written byte to the cached-data
func _write_to_new_byte() -> void:
	_data.append(_byte)
	_byte = 0
	_bit_pointer = POINTER_RESET

## Writes one bit to the Byte-Array
func write_bit(value: int) -> void:
	_byte |= (value << _bit_pointer)
	_bit_pointer -= 1


## Writes a bool to the Byte-Array
func write_bool_flag(value: bool) -> void:
	write_bit(int(value))

## Writes the 'bits'-many bits of an integer to the Byte-Array
func write_int(value: int, bits: int) -> void:
	for bit in bits:
		write_bit(value & (1 << bit) != 0)

## Writes the 'bits'-amount of bits of a signed-integer to the Byte-Array
func write_signed_int(value: int, bits: int) -> void:
	write_int(abs(value), bits)
	write_bool_flag(value < 0)

## Writes a integer with the minimum amount of bytes possible (calculates on its own). [br]
## Note that this is inefficient with integers > 16777215, as this has a custom bit-header
func write_var_int(value: int) -> void:
	var byteMask: int = 0b11111111 << 56
	var bytesToWrite: int = 1
	for intbyte in 8:
		if (value & byteMask) != 0:
			bytesToWrite = (8-intbyte)
			break
		byteMask = byteMask >> 8
	
	write_int(bytesToWrite, 3)
	write_int(value, bytesToWrite*8)

## Writes a signed integer with the minimum amount of bytes possible (calculates on its own). [br]
## Note that this is inefficient with integers > 16777215, as this has a custom bit-header
func write_signed_var_int(value: int) -> void:
	write_var_int(abs(value))
	write_bool_flag(value < 0)

## Returns the Byte-Array with the written bits inside of it. [br]
## This also clears the current data, so you can start with an empty byte-array again
func get_byte_array() -> PackedByteArray:
	if _bit_pointer != POINTER_RESET:
		_write_to_new_byte()
	
	var byteArray: PackedByteArray = []
	byteArray.resize(_data.size())
	for i: int in _data.size():
		byteArray.encode_s8(i, _data[i])
	_data.clear()
	
	return byteArray

## returns the amount of bits written. Useful for debugging
func bits_written() -> int:
	return (_data.size()*8) + (7 - _bit_pointer)
```

## BitReader
```
class_name BitReader extends RefCounted

## This class reads Bits from a [PackedByteArray]
##
## Its supposed to be used in conjunction with the [BitWriter],
## which allows for custom data compression

## The reset position of the bit-pointer
const POINTER_RESET: int = 7

## The byte-array the Reader reads from
var _data: PackedByteArray
## The current byte thats being read
var _byte: int
## Points to the currently read byte inside the byte-array
var _byte_pointer: int = 0
## Points to the current bit the reader is reading
var _bit_pointer: int = POINTER_RESET:
	set(value):
		if value < 0:
			_cache_new_byte()
		else:
			_bit_pointer = value

## Set the byte-array thats supposed to be read
func set_byte_array(data: PackedByteArray) -> void:
	_data = data
	_byte_pointer = 0
	_cache_new_byte()

## Loads a new byte from the byte-array
func _cache_new_byte() -> void:
	if _byte_pointer >= _data.size():
		return
	_byte = _data.decode_u8(_byte_pointer)
	_byte_pointer += 1
	_bit_pointer = POINTER_RESET

## Reads a bool from the byte-array
func read_bool_flag() -> bool:
	var value: bool = (_byte & (1 << _bit_pointer)) != 0
	_bit_pointer -= 1
	return value

## Reads an integer with the given amount of bits from the byte-array
func read_int(bits: int) -> int:
	var value: int = 0
	for bit in bits:
		var bitValue = (_byte & (1 << _bit_pointer)) >> _bit_pointer
		value |= (bitValue << bit)
		_bit_pointer -= 1
	return value

## Reads an integer with the given amount of bits from the byte-array + 1 extra bit to check if the integer is negative
func read_signed_int(bits: int) -> int:
	var value = read_int(bits)
	if read_bool_flag():
		value = -value
	return value

## Reads a integer that has been written with [method BitWriter.write_var_int]
func read_var_int() -> int:
	return read_int(read_int(3)*8)

## Reads a signed-integer that has been written with [method BitWriter.write_signed_var_int]
func read_signed_var_int() -> int:
	var value = read_var_int()
	if read_bool_flag():
		value = -value
	return value

```

# Conclusion
This is my first real contribution to the Godot-Ecosystem. I really enjoy this community and hope this can be useful somehow.

I would love to hear your feedback/improvements.

HerrSpaten
