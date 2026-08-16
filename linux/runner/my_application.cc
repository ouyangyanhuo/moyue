#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static const gchar* get_localized_application_name() {
  const gchar* const* languages = g_get_language_names();
  return languages != nullptr && languages[0] != nullptr &&
                 g_str_has_prefix(languages[0], "zh")
             ? "墨阅"
             : "Moyue";
}

static gboolean is_dark_theme() {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings == nullptr) {
    return FALSE;
  }

  gboolean prefer_dark = FALSE;
  gchar* theme_name = nullptr;
  g_object_get(settings, "gtk-application-prefer-dark-theme", &prefer_dark,
               "gtk-theme-name", &theme_name, nullptr);

  g_autofree gchar* normalized_theme =
      theme_name == nullptr ? nullptr : g_ascii_strdown(theme_name, -1);
  const gboolean theme_name_is_dark =
      normalized_theme != nullptr &&
      g_strrstr(normalized_theme, "dark") != nullptr;
  g_free(theme_name);
  return prefer_dark || theme_name_is_dark;
}

static void update_application_icon(GtkWindow* window) {
  g_autofree gchar* executable_path = g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path == nullptr) {
    return;
  }

  g_autofree gchar* executable_directory = g_path_get_dirname(executable_path);
  const gchar* icon_name =
      is_dark_theme() ? "app_icon_dark.png" : "app_icon_day.png";
  g_autofree gchar* icon_path = g_build_filename(
      executable_directory, "data", icon_name, static_cast<gchar*>(nullptr));
  gtk_window_set_icon_from_file(window, icon_path, nullptr);
}

static void theme_changed_cb(GtkSettings*,
                             GParamSpec*,
                             GtkWindow* window) {
  update_application_icon(window);
}

// 接收到 Flutter 第一帧时调用。
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// 实现 GApplication::activate。
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  const gchar* application_name = get_localized_application_name();
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  update_application_icon(window);

  GtkSettings* settings = gtk_settings_get_default();
  if (settings != nullptr) {
    g_signal_connect_object(settings, "notify::gtk-theme-name",
                            G_CALLBACK(theme_changed_cb), G_OBJECT(window),
                            G_CONNECT_DEFAULT);
    g_signal_connect_object(settings,
                            "notify::gtk-application-prefer-dark-theme",
                            G_CALLBACK(theme_changed_cb), G_OBJECT(window),
                            G_CONNECT_DEFAULT);
  }

  // 在 GNOME 中运行时使用标题栏，因为这是应用程序常用的样式，
  // 也是大多数用户使用的配置（例如 Ubuntu 桌面）。
  // 如果在 X 上运行且不使用 GNOME，则使用传统标题栏，
  // 以应对窗口管理器执行平铺等更特殊的布局。
  // 如果在 Wayland 上运行，则假定标题栏可以正常工作
  //（未来出现其他情况时可能需要修改）。
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, application_name);
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, application_name);
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // 背景默认为黑色；如有需要，可在此处覆盖，例如使用 #00000000 表示透明。
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Flutter 开始渲染时显示窗口。
  // 需要先实现视图，才能开始渲染。
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// 实现 GApplication::local_command_line。
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // 去掉第一个参数，因为它是二进制文件名。
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// 实现 GApplication::startup。
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // 执行应用程序启动时所需的操作。

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// 实现 GApplication::shutdown。
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // 执行应用程序关闭时所需的操作。

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// 实现 GObject::dispose。
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // 将程序名称设置为应用程序 ID，帮助 GTK 和桌面环境等系统将正在运行的应用
  // 映射到对应的 .desktop 文件。这样可以让应用程序不只通过二进制文件名被识别，
  // 从而实现更好的集成。
  g_set_prgname(APPLICATION_ID);
  g_set_application_name(get_localized_application_name());

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
