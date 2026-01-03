# activate-clash-core
这是终端无图形化页面通过clash内核启动clash的运行脚本

注意，这需要你自己有一个clash-verge的订阅链接，并且找到你的配置文件，clash-verge的下载链接如下
https://github.com/Clash-Verge-rev/clash-verge-rev/releases

订阅链接可通过狗狗加速免费获取，也可以在狗狗加速自行购买：狗狗加速网址如下
https://panel.dg5.biz/

配置文件怎么找：
首先打开clash-verge，然后点击订阅，右键你的订阅文件然后点击编辑文件，最后将内容复制到config.yaml即可
注意，这里的config.yaml文件是一个示例，实际还需要你自己去获取配置。

## 怎么使用

- 下载脚本:

```
$ git clone https://github.com/HaoTang9878/activate-clash-core.git
$ cd activate-clash-core
```

- 赋予执行权限:

```
chmod +x activate select-node.sh clash setup-alias.sh
```

- 开启clash 代理:

```
./activate
```
- 这样已经完成全部配置，如果要自行选择节点，可看下面操作
- 选择代理节点:
```
./select-node.sh
```
- 如果要配置环境变量，为大家准备了一个自动脚本，可直接运行：

```
./setup-alias.sh
```

运行后会自动将以下格式的alias添加到你的bashrc文件中：
```
alias activate-clash='source /path/to/activate-clash-core/activate'
alias select-node='/path/to/activate-clash-core/select-node.sh'
```

其中 `/path/to/activate-clash-core` 是脚本自动获取的实际安装路径，无需手动修改。
