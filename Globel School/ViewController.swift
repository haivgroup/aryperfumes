import UIKit
import WebKit
import AVFoundation
import OneSignal

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, WKScriptMessageHandler {

    var webview: WKWebView!
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var scannerView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        // WebView setup
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "startBarcodeScan")
        webview = WKWebView(frame: view.bounds, configuration: config)
        webview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webview)

        requestCameraPermissionIfNeeded()
        loadWebView()
    }

    func loadWebView() {
        let userId = OneSignal.getDeviceState()?.userId ?? "0000"
        if let url = URL(string: "https://www.aryperfumes.com/index.php?app=yes&playerid=\(userId)") {
            webview.load(URLRequest(url: url))
        }
    }

    func requestCameraPermissionIfNeeded() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print(granted ? "Camera Granted" : "Camera Denied")
        }
    }

    // JS bridge
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "startBarcodeScan" {
            startNativeScanner()
        }
    }

    func startNativeScanner() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }

        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(input) { captureSession.addInput(input) }
        } catch {
            print("Camera input error:", error)
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .upce, .code128, .qr] // perfume barcodes
        }

        // Preview
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.bounds
        previewLayer?.videoGravity = .resizeAspectFill

        scannerView = UIView(frame: view.bounds)
        if let scannerView = scannerView, let previewLayer = previewLayer {
            scannerView.layer.addSublayer(previewLayer)
            view.addSubview(scannerView)
        }

        captureSession.startRunning()
    }

    // Barcode detected
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject else { return }
        guard let code = metadataObj.stringValue else { return }

        captureSession?.stopRunning()
        scannerView?.removeFromSuperview()
        captureSession = nil
        scannerView = nil

        // Send barcode back to WebView and submit form
        // Send barcode back to JavaScript function
        let js = "window.onBarcodeScanned('\(code)');"
        webview.evaluateJavaScript(js, completionHandler: nil)
    }
}
