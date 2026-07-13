local MINIZIP_DIR = "../thirdparty/minizip-ng"
local LZMA_DIR = MINIZIP_DIR .. "/lib/liblzma/src/"

project "minizip"
	kind "StaticLib"
	language "C"

	-- Core minizip sources used by RetroPlug (zipp.h). Optional codecs are
	-- platform-specific so arm64 macOS is not forced through x86-only paths.
	files {
		MINIZIP_DIR .. "/mz.h",
		MINIZIP_DIR .. "/mz_os.h",
		MINIZIP_DIR .. "/mz_os.c",
		MINIZIP_DIR .. "/mz_strm.h",
		MINIZIP_DIR .. "/mz_strm.c",
		MINIZIP_DIR .. "/mz_strm_buf.h",
		MINIZIP_DIR .. "/mz_strm_buf.c",
		MINIZIP_DIR .. "/mz_strm_mem.h",
		MINIZIP_DIR .. "/mz_strm_mem.c",
		MINIZIP_DIR .. "/mz_strm_split.h",
		MINIZIP_DIR .. "/mz_strm_split.c",
		MINIZIP_DIR .. "/mz_strm_zlib.h",
		MINIZIP_DIR .. "/mz_strm_zlib.c",
		MINIZIP_DIR .. "/mz_strm_pkcrypt.h",
		MINIZIP_DIR .. "/mz_strm_pkcrypt.c",
		MINIZIP_DIR .. "/mz_strm_wzaes.h",
		MINIZIP_DIR .. "/mz_strm_wzaes.c",
		MINIZIP_DIR .. "/mz_crypt.h",
		MINIZIP_DIR .. "/mz_crypt.c",
		MINIZIP_DIR .. "/mz_zip.h",
		MINIZIP_DIR .. "/mz_zip.c",
		MINIZIP_DIR .. "/mz_zip_rw.h",
		MINIZIP_DIR .. "/mz_zip_rw.c",
	}

	includedirs {
		MINIZIP_DIR,
	}

	defines {
		"HAVE_ZLIB",
	}

	configuration { "Debug" }
		defines { "ZLIB_DEBUG" }

	filter "system:windows"
		disablewarnings { "4267", "4244", "4311" }

		defines {
			"WIN32",
			"_WINDOWS",
			"_CRT_SECURE_NO_WARNINGS",
			"NO_FSEEKO",
			"HAVE_BZIP2",
			"HAVE_LZMA",
			"LZMA_API_STATIC",
			"BZ_NO_STDIO",
		}

		includedirs {
			MINIZIP_DIR .. "/lib/zlib",
			MINIZIP_DIR .. "/lib/bzip2",
			LZMA_DIR,
			LZMA_DIR .. "common",
			LZMA_DIR .. "liblzma/common",
			LZMA_DIR .. "liblzma/api",
			LZMA_DIR .. "liblzma/check",
			LZMA_DIR .. "liblzma/lz",
			LZMA_DIR .. "liblzma/lzma",
			LZMA_DIR .. "liblzma/delta",
			LZMA_DIR .. "liblzma/rangecoder",
			LZMA_DIR .. "liblzma/simple",
		}

		files {
			MINIZIP_DIR .. "/mz_crypt_win32.c",
			MINIZIP_DIR .. "/mz_strm_os_win32.c",
			MINIZIP_DIR .. "/mz_os_win32.c",
			MINIZIP_DIR .. "/mz_strm_bzip.h",
			MINIZIP_DIR .. "/mz_strm_bzip.c",
			MINIZIP_DIR .. "/mz_strm_lzma.h",
			MINIZIP_DIR .. "/mz_strm_lzma.c",
			MINIZIP_DIR .. "/lib/zlib/*.h",
			MINIZIP_DIR .. "/lib/zlib/*.c",
			MINIZIP_DIR .. "/lib/bzip2/*.h",
			MINIZIP_DIR .. "/lib/bzip2/blocksort.c",
			MINIZIP_DIR .. "/lib/bzip2/bzlib.c",
			MINIZIP_DIR .. "/lib/bzip2/compress.c",
			MINIZIP_DIR .. "/lib/bzip2/crctable.c",
			MINIZIP_DIR .. "/lib/bzip2/decompress.c",
			MINIZIP_DIR .. "/lib/bzip2/huffman.c",
			MINIZIP_DIR .. "/lib/bzip2/randtable.c",
		}

	filter "system:macosx"
		defines {
			"_GNU_SOURCE",
		}

		files {
			MINIZIP_DIR .. "/mz_crypt_apple.c",
			MINIZIP_DIR .. "/mz_strm_os_posix.c",
			MINIZIP_DIR .. "/mz_os_posix.c",
		}

		-- Prefer the macOS SDK zlib (arm64-clean).
		links { "z" }

	filter "system:linux"
		defines {
			"MYTHREAD_POSIX",
		}
		files {
			MINIZIP_DIR .. "/mz_strm_os_posix.c",
			MINIZIP_DIR .. "/mz_os_posix.c",
		}
		links { "z" }

	filter {}
