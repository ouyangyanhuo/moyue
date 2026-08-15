#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// 为进程创建控制台，并将 runner 和 Flutter 库的 stdout、stderr 重定向到该控制台。
void CreateAndAttachConsole();

// 接收以 UTF-16 编码且以空字符结尾的 wchar_t*，返回以 UTF-8 编码的 std::string。
// 失败时返回空 std::string。
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// 获取以 std::vector<std::string> 传入的命令行参数，并将其编码为 UTF-8。
// 失败时返回空的 std::vector<std::string>。
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_
