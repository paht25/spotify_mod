<<<<<<< HEAD
import Foundation

extension UcsResponse {
    var assignedValues: [AssignedValue] {
        get {
            self.resolve.configuration.assignedValues
        }
        set(assignedValues) {
            self.resolve.configuration.assignedValues = assignedValues
        }
    }
}
=======
import Foundation

extension UcsResponse {
    var assignedValues: [AssignedValue] {
        get {
            self.resolve.configuration.assignedValues
        }
        set(assignedValues) {
            self.resolve.configuration.assignedValues = assignedValues
        }
    }
}
>>>>>>> 696afedd902c1a3976110c952a8f1a45a39bf9c2
