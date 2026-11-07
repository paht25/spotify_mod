<<<<<<< HEAD
import Foundation

extension BootstrapMessage {
    var ucsResponse: UcsResponse {
        get {
            self.wrapper.oneMoreWrapper.message.response
        }
        set(ucsResponse) {
            self.wrapper.oneMoreWrapper.message.response = ucsResponse
        }
    }
    
    var attributes: Dictionary<String, AccountAttribute> {
        get {
            self.ucsResponse.attributes.accountAttributes
        }
        set(attributes) {
            self.ucsResponse.attributes.accountAttributes = attributes
        }
    }
}
=======
import Foundation

extension BootstrapMessage {
    var ucsResponse: UcsResponse {
        get {
            self.wrapper.oneMoreWrapper.message.response
        }
        set(ucsResponse) {
            self.wrapper.oneMoreWrapper.message.response = ucsResponse
        }
    }
    
    var attributes: Dictionary<String, AccountAttribute> {
        get {
            self.ucsResponse.attributes.accountAttributes
        }
        set(attributes) {
            self.ucsResponse.attributes.accountAttributes = attributes
        }
    }
}
>>>>>>> 696afedd902c1a3976110c952a8f1a45a39bf9c2
