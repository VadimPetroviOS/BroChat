//
//  MessagesViewController.swift
//  BROChat
//
//  Created by Вадим on 16.08.2022.
//

import UIKit
import Firebase

class MessagesViewController: UIViewController {
    
    var partnerUser: User?
    var messages = [Message]()
    let currentUserUid = Auth.auth().currentUser?.uid
    var listenerForUserMessages: ListenerRegistration?
    var listenerForPartnerMessages: ListenerRegistration?
    var listenerActivity: ListenerRegistration?

    override func loadView() {
        self.view = MessagesView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view().messageCreator.messageField.delegate = self
        view().messageCreator.delegate = self
        view().backgroundColor = Constants.Colors.grayBackground
        observeActivity()
        observeMessages()
        configTableView()
        configNavBar()
    }
    
    fileprivate func view() -> MessagesView {
        return self.view as? MessagesView ?? MessagesView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
        if isMovingFromParent {
            listenerActivity?.remove()
            listenerForUserMessages?.remove()
            listenerForPartnerMessages?.remove()
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    
    fileprivate func configTableView() {
        view().messageScene.register(MessageCell.self, forCellReuseIdentifier: "cell")
        view().messageScene.separatorStyle = .none
        view().messageScene.delegate = self
        view().messageScene.dataSource = self
    }

    fileprivate func configNavBar() {
        guard let user = partnerUser else { return }

        navigationItem.largeTitleDisplayMode = .never
        let avatarView = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        let image = UIImageView(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        image.loadImage(with: user.profileImageUrl)
        image.layer.cornerRadius = 18
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        avatarView.addSubview(image)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: avatarView)
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                               as? NSValue)?.cgRectValue {
            self.view().bottomConstraint?.constant = -keyboardSize.height
            self.view().layoutIfNeeded()
            scrollToLastmessage()
        }
    }
    
    @objc  func keyboardWillHide() {
        self.view().bottomConstraint?.constant = 0
        self.view().layoutIfNeeded()
    }
    
    fileprivate func observeMessages() {
        guard let partnerUser = partnerUser else { return }

        FirestoreManager.shared.messageManager.recieveMessages(from: currentUserUid, to: partnerUser.uid) { message in
            if !self.messages.contains(where: {$0.text == message.text && $0.date == message.date}) {
                self.messages.append(message)
                self.sortMessages()
            }
        } listener: { listener in
            self.listenerForUserMessages = listener
        }
        FirestoreManager.shared.messageManager.recieveMessages(from: partnerUser.uid, to: currentUserUid) { message in
            if !self.messages.contains(where: {$0.text == message.text && $0.date == message.date}) {
                self.messages.append(message)
                self.sortMessages()
            }
        } listener: { listener in
                self.listenerForPartnerMessages = listener
        }
    }
    
    fileprivate func sortMessages() {
        messages = messages.sorted(by: {$0.date < $1.date})
        DispatchQueue.main.async {
            self.view().messageScene.reloadData()
            let indexPath = IndexPath(row: self.messages.count-1, section: 0)
            self.view().messageScene.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
    
    
    func observeActivity() {
        guard let partnerUser = partnerUser else { return }

        FirestoreManager.shared.userManager.observeActivity(userUid: partnerUser.uid) { status, latestActivity in
           let latestOnline = latestActivity.convertToTimeString()
            self.view().configStatusLabel(user: partnerUser, activieStatus: status, latestActivity: latestOnline)
            self.navigationItem.titleView = self.view().titleLabel
        } listener: { listener in
            self.listenerActivity = listener
        }
    }

    fileprivate func scrollToLastmessage() {
        if self.messages.count > 1 {
            let indexPath = IndexPath(row: self.messages.count-1, section: 0)
            self.view().messageScene.scrollToRow(at: indexPath, at: .top, animated: false)
        }
    }
    
    deinit {
        print("message view destroyed")
     }
}
extension MessagesViewController: MessageCreatorDelegate {
    func sendAction() {
        guard let text = view().messageCreator.messageField.text else { return }
        guard let partnerUser = partnerUser else { return }
        
        FirestoreManager.shared.messageManager.sendMessageToFirebase(text: text, from: currentUserUid, to: partnerUser.uid)
        DispatchQueue.main.async {
            self.scrollToLastmessage()
            self.view().messageCreator.messageField.text = ""
        }
    }
}

extension MessagesViewController: UITextFieldDelegate {
    func textFieldDidChangeSelection(_ textField: UITextField) {
        if let text = textField.text {
            if !text.isEmpty {
                self.view().messageCreator.sendButton.isEnabled = true
                self.view().messageCreator.sendButton.tintColor = .systemBlue
            } else {
                self.view().messageCreator.sendButton.isEnabled = false
                self.view().messageCreator.sendButton.tintColor = .lightGray
            }
        }
    }
}

extension MessagesViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell",
                                                 for: indexPath) as! MessageCell
        cell.message = messages[indexPath.row]
        cell.selectionStyle = .none
        return cell
    }
}
