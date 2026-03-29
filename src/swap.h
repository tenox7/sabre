#include <inttypes.h>

#ifdef __APPLE__
#include <libkern/OSByteOrder.h>
#define htole16(x) OSSwapHostToLittleInt16(x)
#define htole32(x) OSSwapHostToLittleInt32(x)
#else
#include <endian.h>
#endif

static int16_t ltohs(int16_t x);
static inline int16_t ltohs(int16_t x)
{
#ifdef __cplusplus
	return static_cast<int16_t>(htole16(static_cast<uint16_t>(x)));
#else
	return htole16(x);
#endif
}

static int32_t ltohl(int32_t x);
static inline int32_t ltohl(int32_t x)
{
#ifdef __cplusplus
	return static_cast<int32_t>(htole32(static_cast<uint32_t>(x)));
#else
	return htole32(x);
#endif
}
