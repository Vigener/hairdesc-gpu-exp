#pragma once

#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <vector>

inline std::vector<double> read_double_file(const char* path) {
	std::FILE* fp = std::fopen(path, "rb");
  // エラー処理: ファイルが開けない、サイズが不正、読み込みに失敗など
	if (fp == nullptr) {
		std::fprintf(stderr, "file not found: %s\n", path);
		std::exit(1);
	}

	if (std::fseek(fp, 0, SEEK_END) != 0) {
		std::fprintf(stderr, "failed to seek: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	const long file_size = std::ftell(fp);
	if (file_size < 0) {
		std::fprintf(stderr, "failed to get size: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	if (file_size % static_cast<long>(sizeof(double)) != 0) {
		std::fprintf(stderr, "invalid double file size: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	if (std::fseek(fp, 0, SEEK_SET) != 0) {
		std::fprintf(stderr, "failed to rewind: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

  // ファイルサイズから要素数を計算して読み込む
	const std::size_t count = static_cast<std::size_t>(file_size / static_cast<long>(sizeof(double)));
	std::vector<double> values(count);
	if (!values.empty() && std::fread(values.data(), sizeof(double), count, fp) != count) {
		std::fprintf(stderr, "failed to read: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	std::fclose(fp);
	return values;
}

inline std::vector<double> read_double_file(const char* path, std::size_t count) {
	std::FILE* fp = std::fopen(path, "rb");
	if (fp == nullptr) {
		std::fprintf(stderr, "file not found: %s\n", path);
		std::exit(1);
	}

	if (std::fseek(fp, 0, SEEK_END) != 0) {
		std::fprintf(stderr, "failed to seek: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	const long file_size = std::ftell(fp);
	if (file_size < 0) {
		std::fprintf(stderr, "failed to get size: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	if (file_size % static_cast<long>(sizeof(double)) != 0) {
		std::fprintf(stderr, "invalid double file size: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	const std::size_t available = static_cast<std::size_t>(file_size / static_cast<long>(sizeof(double)));
	if (available < count) {
		std::fprintf(stderr, "file has fewer elements than requested: %s (available=%zu, requested=%zu)\n", path, available, count);
		std::fclose(fp);
		std::exit(1);
	}

	if (std::fseek(fp, 0, SEEK_SET) != 0) {
		std::fprintf(stderr, "failed to rewind: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	std::vector<double> values(count);
	if (!values.empty() && std::fread(values.data(), sizeof(double), count, fp) != count) {
		std::fprintf(stderr, "failed to read: %s\n", path);
		std::fclose(fp);
		std::exit(1);
	}

	std::fclose(fp);
	return values;
}