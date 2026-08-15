cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# 定义应用程序目标。如需更改名称，请修改顶层 CMakeLists.txt 中的 BINARY_NAME，
# 不要修改此处的值，否则 `flutter run` 将无法正常工作。
#
# 添加到应用程序的任何新源文件都应列在此处。
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# 应用标准构建设置。对于需要不同构建设置的应用程序，可以删除此项。
apply_standard_settings(${BINARY_NAME})

# 添加构建版本的预处理器定义。
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# 禁用与 C++ 标准库函数冲突的 Windows 宏。
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# 添加依赖库和包含目录。应用程序专用的依赖项可在此处添加。
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# 运行 Flutter 工具负责的构建部分。不得删除此项。
add_dependencies(${BINARY_NAME} flutter_assemble)
