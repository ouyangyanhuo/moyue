import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

String localizedApplicationName(Locale locale) {
  return locale.languageCode.toLowerCase() == 'zh' ? '墨阅' : 'Moyue';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 此组件是应用程序的根组件。
  @override
  Widget build(BuildContext context) {
    final appName = localizedApplicationName(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    return MaterialApp(
      title: appName,
      theme: ThemeData(
        // 这是应用程序的主题配置。
        //
        // 试试看：使用“flutter run”运行应用程序，你会看到应用程序显示一条紫色工具栏。
        // 在不退出应用程序的情况下，尝试将下方 colorScheme 中的 seedColor
        // 改为 Colors.green，然后执行“热重载”（保存更改，或在支持 Flutter 的
        // IDE 中按下“热重载”按钮；如果你通过命令行启动应用程序，也可以按“r”键）。
        //
        // 请注意，计数器并未重置为零；应用程序状态不会在热重载期间丢失。
        // 如果要重置状态，请改用热重启。
        //
        // 这一机制不仅适用于数值，也适用于代码：大多数代码更改只需通过热重载
        // 即可进行测试。
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MyHomePage(title: appName),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // 此组件是应用程序的主页。它是有状态组件，这意味着它拥有一个 State 对象
  //（定义见下方），其中包含会影响其外观的字段。

  // 此类是状态的配置类。它保存由父组件（这里是 App 组件）提供，并由 State 的
  // build 方法使用的值（这里是标题）。Widget 子类中的字段始终标记为“final”。

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // 调用 setState 会告知 Flutter 框架此 State 中的内容发生了变化，从而使其
      // 重新运行下方的 build 方法，让界面能够反映更新后的值。如果只修改
      // _counter 而不调用 setState()，build 方法就不会再次执行，界面上也不会
      // 显示任何变化。
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 每次调用 setState 时，此方法都会重新运行，例如上方的 _incrementCounter
    // 方法所执行的操作。
    //
    // Flutter 框架针对 build 方法的重复运行进行了优化，因此可以直接重新构建
    // 所有需要更新的内容，而不必逐个修改组件实例。
    return Scaffold(
      appBar: AppBar(
        // 试试看：尝试将这里的颜色改为某种指定颜色（例如 Colors.amber），然后
        // 触发热重载，观察 AppBar 改变颜色，而其他颜色保持不变。
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // 这里获取由 App.build 方法创建的 MyHomePage 对象中的值，并用它设置
        // 应用栏的标题。
        title: Text(widget.title),
      ),
      body: Center(
        // Center 是一个布局组件。它接收一个子组件，并将其放置在父组件的中央。
        child: Column(
          // Column 也是一个布局组件。它接收一组子组件，并将它们垂直排列。
          // 默认情况下，它会在水平方向上调整自身大小以适应子组件，并尽可能
          // 与父组件保持相同高度。
          //
          // Column 提供了多种属性，用于控制自身尺寸以及子组件的位置。这里使用
          // mainAxisAlignment 将子组件垂直居中；由于 Column 沿垂直方向排列，
          // 因此这里的主轴是垂直轴（交叉轴则是水平轴）。
          //
          // 试试看：启用“调试绘制”（在 IDE 中选择“Toggle Debug Paint”操作，
          // 或在控制台中按“p”键），即可查看每个组件的线框。
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
