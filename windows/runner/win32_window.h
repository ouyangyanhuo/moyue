#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// 支持高 DPI 的 Win32 窗口类抽象。供需要自定义渲染和输入处理的类继承。
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // 创建标题为 |title| 的 Win32 窗口，并使用 |origin| 和 |size| 设置位置与大小。
  // 新窗口会在默认显示器上创建。窗口大小以物理像素传递给操作系统，因此此函数
  // 会根据默认显示器适当缩放输入的宽度和高度，以确保大小一致。调用 |Show|
  // 之前窗口不可见。窗口创建成功时返回 true。
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // 显示当前窗口。窗口成功显示时返回 true。
  bool Show();

  // 释放与窗口关联的操作系统资源。
  void Destroy();

  // 将 |content| 插入窗口树。
  void SetChildContent(HWND content);

  // 返回底层窗口句柄，供调用方设置图标和其他窗口属性。
  // 如果窗口已销毁，则返回 nullptr。
  HWND GetHandle();

  // 如果为 true，关闭此窗口将退出应用程序。
  void SetQuitOnClose(bool quit_on_close);

  // 返回表示当前客户区边界的 RECT。
  RECT GetClientArea();

 protected:
  // 处理并分派与鼠标操作、大小变化和 DPI 相关的重要窗口消息。
  // 将这些消息交由继承类可以处理的成员重载函数处理。
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // 调用 CreateAndShow 时调用，以便子类执行窗口相关设置。
  // 如果设置失败，子类应返回 false。
  virtual bool OnCreate();

  // 调用 Destroy 时调用。
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // 由消息泵调用的操作系统回调。处理创建非客户区时传递的 WM_NCCREATE 消息，
  // 并启用非客户区 DPI 自动缩放，使非客户区能够自动响应 DPI 变化。
  // 其他所有消息均由 MessageHandler 处理。
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // 获取 |window| 对应的类实例指针。
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // 更新窗口框架主题，使其与系统主题匹配。
  static void UpdateTheme(HWND const window);

  bool quit_on_close_ = false;

  // 顶层窗口的窗口句柄。
  HWND window_handle_ = nullptr;

  // 承载内容的窗口句柄。
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
