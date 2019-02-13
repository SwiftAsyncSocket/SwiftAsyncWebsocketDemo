//
//  ViewController.swift
//  SwiftAsyncWebsocket
//
//  Created by chouheiwa on 2019/2/2.
//  Copyright © 2019 chouheiwa. All rights reserved.
//

import UIKit
import SwiftAsyncWebsocket
class ViewController: UIViewController {
    var formatter: DateFormatter!

    var websocket: SwiftAsyncWebsocket?

    var dataArray: [WebsocketModel] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    var isConnecting: Bool = false {
        didSet {
            connectionButton.isEnabled = !isConnecting
        }
    }

    var connected: Bool = false {
        didSet {
            connectedTextField.isEnabled = !connected
            connectionButton.setTitle(connected ? "断开" : "连接", for: .normal)
            messageTextField.isEnabled = connected
            sendButton.isEnabled = connected

            if !connected {
                dataArray.removeAll()
                messageTextField.text = nil
            }
        }
    }

    @IBOutlet weak var connectedTextField: UITextField!
    @IBOutlet weak var connectionButton: UIButton!
    
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        formatter = DateFormatter()

        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        connected = false

        connectedTextField.text = "ws://demos.kaazing.com/echo"

        tableView.register(UINib(nibName: "WebsocketMessageTableViewCell",
                                 bundle: nil),
                           forCellReuseIdentifier: "cellId")

        tableView.dataSource = self

        tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
    @IBAction func connectAction(_ sender: Any) {
        isConnecting = true

        if connected {
            websocket?.close()
        } else {
            guard let url = URL(string: connectedTextField.text ?? "") else {
                showAlert("URL生成失败")
                return
            }

            let request = URLRequest(url: url)

            do {
                let header = try RequestHeader(request: request)

                websocket = SwiftAsyncWebsocket(requestHeader: header, delegate: self, delegateQueue: DispatchQueue.main)

                try websocket?.connect()
            } catch let error as WebsocketError {
                showAlert("\(error)")
            } catch {
                fatalError()
            }
        }
    }
    @IBAction func sendTextAction(_ sender: Any) {
        guard let text = messageTextField.text, (text.count > 0) else {
            showAlert("请不要发送空字符串")
            return
        }

        websocket?.send(text: text)

        let model = WebsocketModel(sender: .client,
                                   message: .text,
                                   detail: text,
                                   date: formatter.string(from: Date()))

        dataArray.append(model)
    }
}

extension ViewController: SwiftAsyncWebsocketDelegate {
    func websocketDidConnect(_ websocket: SwiftAsyncWebsocket) {

    }

    func websocket(_ websocekt: SwiftAsyncWebsocket, didCloseWith code: UInt16, reason: String?) {
        connected = false
        isConnecting = false
    }

    func websocket(_ websocket: SwiftAsyncWebsocket, didReceive messgae: Any, type: Opcode, isFinalData fin: Bool) {
        var opeationCode: WebsocketModel.MessageType

        if type == .TEXT {
            opeationCode = .text
        } else {
            opeationCode = .binary
        }

        let model = WebsocketModel(sender: .server,
                                   message: opeationCode,
                                   detail: messgae,
                                   date: formatter.string(from: Date()))

        dataArray.append(model)
    }

    func websocket(_ websocket: SwiftAsyncWebsocket, didReceivePong data: Data) {
        let model = WebsocketModel(sender: .server,
                                   message: .pong,
                                   detail: String(data: data, encoding: .utf8) ?? "",
                                   date: formatter.string(from: Date()))

        dataArray.append(model)
    }
    func websocket(_ websocket: SwiftAsyncWebsocket, failedConnect error: WebsocketError?) {
        if let error = error {
            showAlert("连接失败\n原因:\(error)")
        }

        connected = false
        isConnecting = false
    }

    func websocket(_ websocket: SwiftAsyncWebsocket, didReceivePing data: Data) -> Data? {
        let model = WebsocketModel(sender: .server,
                                   message: .ping,
                                   detail: String(data: data, encoding: .utf8) ?? "数据为空",
                                   date: formatter.string(from: Date()))

        dataArray.append(model)

        let modelClient = WebsocketModel(sender: .client,
                                   message: .pong,
                                   detail: String(data: data, encoding: .utf8) ?? "数据为空",
                                   date: formatter.string(from: Date()))

        dataArray.append(modelClient)

        return data
    }

    func websocketDidOpen(_ websocket: SwiftAsyncWebsocket) {
        connected = true
        isConnecting = false
    }
}

extension ViewController {
    func showAlert(_ message: String?) {
        let controller = UIAlertController(title: "提示", message: message, preferredStyle: .alert)

        controller.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))

        self.present(controller, animated: true, completion: nil)
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellId", for: indexPath)

        if let itemCell = cell as? WebsocketMessageTableViewCell {
            let index = dataArray.count - indexPath.row - 1
            itemCell.model = dataArray[index]
        }

        return cell
    }
}

