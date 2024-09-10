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
