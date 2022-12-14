//
//  LogActionsManager.swift
//  BROChat
//
//  Created by Вадим on 28.09.2022.
//

import UIKit

class LogActionsManager {
 
    func logIn(_ email: String, _ password: String,
               completion: @escaping ((Error?) -> Void)) {
        
        Constants.FirestoreConst.auth.signIn(withEmail: email, password: password) { authDataResult, error in
            if let error = error {
                completion(error)
                return
            }
            if let _ = authDataResult {
                completion(nil)
                self.changeRootVC()
            }
        }
    }
    
    func logOut() {
        do {
            FirestoreManager.shared.userManager.isOnline(status: false)
            try Constants.FirestoreConst.auth.signOut()
        } catch let error as NSError {
            print("logOut action failed with: \(error.localizedDescription)")
        }
        changeRootVC()

    }
    
    fileprivate func changeRootVC() {
        let scene = UIApplication.shared.connectedScenes.first
        if let sd : SceneDelegate = (scene?.delegate as? SceneDelegate) {
            sd.configureInitialVC()
        }
    }
}

