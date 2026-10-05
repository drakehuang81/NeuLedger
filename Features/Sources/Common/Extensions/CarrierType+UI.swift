import Domain
import SwiftUI

/// `CarrierType` 的圖示與色彩，iOS / Widget / Watch 共用這一份定義。
public extension CarrierType {

    /// iOS 主 App 與 Widget 的圖示。
    var systemImageName: String {
        switch self {
        case .phoneBarcodeCarrier:       return "iphone"
        case .citizenDigitalCertificate: return "creditcard"
        }
    }

    /// Watch 的圖示，刻意與 iOS 不同。
    ///
    /// `iphone.gen3` 在手錶尺寸下比 `iphone` 清楚，而 `person.text.rectangle`
    /// 表達的是「身分證件」、`creditcard` 表達的是「支付卡」——自然人憑證不是
    /// 支付卡，所以 Watch 這組在語意上更準。
    ///
    /// 這個 task 的目的是把散在各 View 裡的 `switch` 收斂成一份定義，不是
    /// 把兩個平台壓成同一組圖示：後者會是一次沒有記錄理由的視覺變更。所以
    /// 兩組都放在這裡，差異本身變成顯式且有說明的。
    var watchSystemImageName: String {
        switch self {
        case .phoneBarcodeCarrier:       return "iphone.gen3"
        case .citizenDigitalCertificate: return "person.text.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .phoneBarcodeCarrier:       return Color.Design.accentOrange
        case .citizenDigitalCertificate: return Color.Design.carrierCertIndigo
        }
    }
}
