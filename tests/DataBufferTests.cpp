#include <cassert>
#include <cstdint>
#include <stdexcept>

#include "retroplug/util/DataBuffer.h"

int main() {
	DataBuffer<char> buffer(4);
	const char initial[] = { 1, 2, 3, 4 };
	buffer.write(initial, sizeof(initial));

	buffer.resize(8);
	assert(buffer.size() == 8);
	assert(buffer.capacity() >= 8);
	for (size_t i = 0; i < sizeof(initial); ++i) {
		assert(buffer.get(i) == initial[i]);
	}

	buffer.resize(2);
	assert(buffer.size() == 2);
	assert(buffer.capacity() >= 8);
	assert(buffer.get(0) == 1);
	assert(buffer.get(1) == 2);

	char externalData[] = { 5, 6, 7, 8 };
	DataBuffer<char> external(externalData, sizeof(externalData), false);
	assert(external.size() == sizeof(externalData));
	external.clear();
	for (char value : externalData) {
		assert(value == 0);
	}

	bool rejectedGrowth = false;
	try {
		external.resize(sizeof(externalData) + 1);
	} catch (const std::logic_error&) {
		rejectedGrowth = true;
	}
	assert(rejectedGrowth);

	DataBuffer<char> bytes(5);
	const char encoded[] = { 0, 0x78, 0x56, 0x34, 0x12 };
	bytes.write(encoded, sizeof(encoded));
	assert(bytes.readUint32(1) == UINT32_C(0x12345678));

	bool rejectedRead = false;
	try {
		bytes.readUint32(2);
	} catch (const std::out_of_range&) {
		rejectedRead = true;
	}
	assert(rejectedRead);

	return 0;
}
