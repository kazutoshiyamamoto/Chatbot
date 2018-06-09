//
//  ViewController.swift
//  Chatbot
//
//  Created by home on 2018/06/09.
//  Copyright © 2018年 Swift-beginners. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import Alamofire
import SwiftyJSON

class ViewController: JSQMessagesViewController {
    
    // データベースへの参照を定義
    var ref: DatabaseReference!
    
    // メッセージ内容に関するプロパティ
    var messages: [JSQMessage]?
    // 背景画像に関するプロパティ
    var incomingBubble: JSQMessagesBubbleImage!
    var outgoingBubble: JSQMessagesBubbleImage!
    // アバター画像に関するプロパティ
    var incomingAvatar: JSQMessagesAvatarImage!
    var outgoingAvatar: JSQMessagesAvatarImage!
    
    // Repl-AIのユーザーIDを保存する変数
    var id: String!
    // 入力したメッセージを保存する変数
    var msg: String!
    // 返答メッセージを保存する変数
    var response: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // クリーンアップツールバーの設定
        self.inputToolbar!.contentView!.leftBarButtonItem = nil
        // 新しいメッセージを受信するたびに下にスクロールする
        self.automaticallyScrollsToMostRecentMessage = true
        
        // 自分のsenderId, senderDisplayNameを設定
        self.senderId = "user1"
        self.senderDisplayName = "A"
        
        // 吹き出しの設定
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        self.incomingBubble = bubbleFactory?.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())
        self.outgoingBubble = bubbleFactory?.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
        
        // アバターの設定
        self.incomingAvatar = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "snowman")!, diameter: 64)
        self.outgoingAvatar = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "santaclaus")!, diameter: 64)
        
        //メッセージデータの配列を初期化
        self.messages = []
        self.setupFirebase()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // データベースからデータを取得する
    func setupFirebase() {
        // DatabaseReferenceのインスタンス化
        self.ref = Database.database().reference()
        
        // 最新5件のデータをデータベースから取得する
        // 最新のデータが追加されるたびに最新データを取得する
        self.ref.queryLimited(toLast: 10).observe(DataEventType.childAdded, with: { (snapshot) -> Void in
            let snapshotValue = snapshot.value as! NSDictionary
            let text = snapshotValue["text"] as! String
            let sender = snapshotValue["from"] as! String
            let name = snapshotValue["name"] as! String
            let message = JSQMessage(senderId: sender, displayName: name, text: text)
            self.messages?.append(message!)
            self.finishSendingMessage()
        })
    }
    
    // Sendボタンが押された時に呼ばれるメソッド
    override func didPressSend(_ button: UIButton, withMessageText text: String, senderId: String, senderDisplayName: String, date: Date) {
        
        //メッセージの送信処理を完了する(画面上にメッセージが表示される)
        self.finishReceivingMessage(animated: true)
        
        //Firebaseにデータを送信、保存する
        let post1 = ["from": senderId, "name": senderDisplayName, "text":text]
        let post1Ref = self.ref.childByAutoId()
        post1Ref.setValue(post1)
        self.finishSendingMessage(animated: true)
        
        // 入力したテキストをdialogue()のパラメータへ渡す
        self.msg = text
        
        // Repl-AIからユーザーIDと対話内容を取得し返答する
        userId()
    }

    // Repl-AIのユーザーIDを取得
    func userId() {
        let URL = "https://api.repl-ai.jp/v1/registration"
        let headers = [
            "Content-Type": "application/json",
            "x-api-key": ""
        ]
        let parameters = [
            "botId": "sample"
        ]
        
        Alamofire.request(URL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                print(json)
                self.id = json["appUserId"].stringValue
                

                
                self.dialogue()
            case .failure(let error):
                print(error)
            }
        }
    }
    
    // Repl-AIの対話情報の取得
    func dialogue() {
        let URL = "https://api.repl-ai.jp/v1/dialogue"
        let headers = [
            "Content-Type": "application/json",
            "x-api-key": ""
        ]
        let parameters: [String: Any] = [
            "appUserId": self.id,
            "botId": "sample",
            "voiceText": self.msg,
            "initTalkingFlag": false,
            "initTopicId": "docomoapi"
        ]
        
        Alamofire.request(URL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                print(json)
                self.response = json["systemText"]["expression"].stringValue
                self.receiveMessage()
            case .failure(let error):
                print(error)
            }
        }
    }
    
    // メッセージに対して返答した内容をFirebaseに送信、保存する
    func receiveMessage() {
        let post2 = ["from": "user2", "name": "B", "text":response]
        let post2Ref = self.ref.childByAutoId()
        post2Ref.setValue(post2)
    }
    
    // アイテムごとに参照するメッセージデータを返す
    override func collectionView(_ collectionView: JSQMessagesCollectionView, messageDataForItemAt indexPath: IndexPath) -> JSQMessageData {
        return messages![indexPath.item]
    }
    
    // アイテムごとのMessageBubble(背景)を返す
    override func collectionView(_ collectionView: JSQMessagesCollectionView, messageBubbleImageDataForItemAt indexPath: IndexPath) -> JSQMessageBubbleImageDataSource {
        let message = self.messages?[indexPath.item]
        if message?.senderId == self.senderId {
            return self.outgoingBubble
        }
        return self.incomingBubble
    }
    
    // アイテムごとにアバター画像を返す
    override func collectionView(_ collectionView: JSQMessagesCollectionView, avatarImageDataForItemAt indexPath: IndexPath) -> JSQMessageAvatarImageDataSource? {
        let message = self.messages?[indexPath.item]
        if message?.senderId == self.senderId {
            return self.outgoingAvatar
        }
        return self.incomingAvatar
    }
    
    // アイテムの総数を返す
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages!.count
    }
}

