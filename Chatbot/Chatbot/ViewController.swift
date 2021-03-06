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
    
    // Repl-AIのユーザーIDを保持するプロパティ
    var id: String!
    // 送信したメッセージを保持するプロパティ
    var msg: String!
    // Repl-AIからの返答メッセージを保持するプロパティ
    var responseMsg: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // ツールバーの設定
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
        self.incomingAvatar = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "{アバター画像のファイル名}")!, diameter: 64)
        self.outgoingAvatar = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "{アバター画像のファイル名}")!, diameter: 64)
        
        //メッセージデータの配列を初期化
        self.messages = []
        self.setupFirebase()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Firebaseからデータを取得する
    func setupFirebase() {
        // DatabaseReferenceのインスタンス化
        self.ref = Database.database().reference()
        
        // 最新10件のデータをデータベースから取得する
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
        
        //送信したメッセージをFirebaseに保存する
        let post1 = ["from": senderId, "name": senderDisplayName, "text":text]
        let post1Ref = self.ref.childByAutoId()
        post1Ref.setValue(post1)
        self.finishSendingMessage(animated: true)
        
        // 送信したメッセージをdialogue()のパラメータへ渡す
        self.msg = text
        
        // Repl-AIからユーザーIDと返答メッセージを取得する
        userId()
    }

    // Repl-AIのユーザーIDを取得
    func userId() {
        let URL = "{リクエストURL}"
        let headers = [
            "Content-Type": "application/json",
            "x-api-key": "{APIキー}"
        ]
        let parameters = [
            "botId": "{ボットID}"
        ]
        
        Alamofire.request(URL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                self.id = json["appUserId"].stringValue
                self.dialogue()
            case .failure(let error):
                print(error)
            }
        }
    }
    
    // Repl-AIの対話情報の取得
    func dialogue() {
        let URL = "{リクエストURL}"
        let headers = [
            "Content-Type": "application/json",
            "x-api-key": "{APIキー}"
        ]
        let parameters: [String: Any] = [
            "appUserId": self.id,
            "botId": "{ボットID}",
            "voiceText": self.msg,
            "initTalkingFlag": false,
            "initTopicId": "{シナリオID}"
        ]
        
        Alamofire.request(URL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).validate().responseJSON { response in
            switch response.result {
            case .success(let value):
                let json = JSON(value)
                self.responseMsg = json["systemText"]["expression"].stringValue
                self.saveReceiveMessage()
            case .failure(let error):
                print(error)
            }
        }
    }
    
    // 送信メッセージに対して返答した内容をFirebaseに保存する
    func saveReceiveMessage() {
        let post2 = ["from": "user2", "name": "B", "text": responseMsg]
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
