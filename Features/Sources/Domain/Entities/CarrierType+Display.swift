import Foundation

/// `CarrierType` 的文字呈現，取代原本散在三個 iOS 檔案裡的各自實作
/// （`AddEditCarrierView` 的兩個 private func、`AddEditCarrierFeature`
/// 檔尾的 `defaultName` extension）。
///
/// **目前的實際消費者只有 iOS 主 App。** Widget 走 `typeRawValue` 字串、
/// 沒有連結 Domain（Task 14 要處理），Watch 只畫圖示、不顯示型別名稱。
///
/// 字串表的分佈因此值得記一筆：`carrier_type_*` 在 iOS 與 Widget 的
/// xcstrings 都有（Widget 那兩筆目前沒有程式碼在用），`carrier_form_*`
/// 只在 iOS，而 **Watch 的表三者都沒有**。哪天 Watch 要顯示名稱，得先把
/// key 加進該 target 的 xcstrings——否則 `String(localized:)` 會把 key
/// 本身當成翻譯回傳，而那串文字看起來像一個合理的字串、能一路上架。
/// `CarrierTypeDisplayTests` 的 `hasPrefix("carrier_type_")` 斷言守的
/// 就是這一條（它在 iOS 測試 target 跑，所以守得住 iOS，守不住 Watch）。
public extension CarrierType {
    var localizedName: String {
        switch self {
        case .phoneBarcodeCarrier:
            return String(localized: "carrier_type_phone_barcode", bundle: .main)
        case .citizenDigitalCertificate:
            return String(localized: "carrier_type_citizen_cert", bundle: .main)
        }
    }

    /// 表單 placeholder；形狀對應 `AddEditCarrierFeature.validate` 的 regex。
    var barcodePlaceholder: String {
        switch self {
        case .phoneBarcodeCarrier:       return "/XXXXXXX"
        case .citizenDigitalCertificate: return "/PXXXXXXXXXXXXXXXX"
        }
    }

    var barcodeFormatHint: String {
        switch self {
        case .phoneBarcodeCarrier:
            return String(localized: "carrier_form_barcode_hint_phone", bundle: .main)
        case .citizenDigitalCertificate:
            return String(localized: "carrier_form_barcode_hint_cert", bundle: .main)
        }
    }
}
