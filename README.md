# activate-clash-core
这是终端无图形化页面通过clash内核启动clash的运行脚本

注意，这需要你自己有一个clash-verge的订阅链接，并且找到你的配置文件，clash-verge的下载链接如下
https://github.com/Clash-Verge-rev/clash-verge-rev/releases

订阅链接可通过狗狗加速免费获取，也可以在狗狗加速自行购买：狗狗加速网址如下
https://panel.dg5.biz/

配置文件怎么找：
首先打开clash-verge，然后点击订阅，右键你的订阅文件然后点击编辑文件，最后将内容复制到config.yaml即可

## 怎么使用

- 下载脚本:

```
$ git clone https://github.com/HaoTang9878/activate-clash-core.git
$ cd clash
```

- 赋予执行权限:
chmod +x activate select-node.sh clash

- 开启clash 代理:

```
./activate
```
- 这样已经完成全部配置，如果要自行选择节点，可看下面操作
- 选择代理节点:
```
./select-node.sh
```
- 如果要配置环境变量，为大家准备了
