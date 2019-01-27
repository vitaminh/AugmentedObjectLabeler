//
//  ViewController.swift
//  ARKitAndCoreML
//
//  Created by HDO on 1/21/19.
//  Based on ARKit and CoreML implementation by Hanley Weng: https://github.com/hanleyweng/CoreML-in-ARKit
//  Copyright © 2019 Henry Do. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
    var languageIsEnglish: Bool = true
    var selectedLanguage = ["English", "en"]
    
    // Actions
    @IBAction func clearButtonPressed(_ sender: Any) {
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
    }
    
    @IBAction func changeLanguage(_ sender: Any) {
        performSegue(withIdentifier: "languagePickerSegue", sender: nil)
    }
    
    // Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "languagePickerSegue") {
            let destination = segue.destination as! LanguagePickerViewController
            destination.selectedLanguage = selectedLanguage
            print(destination.selectedLanguage)
        }
    }
    
    @IBAction func unwindToThisView(sender: UIStoryboardSegue) {
        if let popOverViewController = sender.source as? LanguagePickerViewController {
            selectedLanguage = popOverViewController.selectedLanguage
        }
        setLanguage()
    }
    
    func setLanguage() {
        // Set language for future objects
        languageButton.setTitle(selectedLanguage[0], for: UIControl.State.normal)
        
        // Change text of existing objects
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            if (node.childNodes.count == 0) {
                return
            }
            var newNodeText = node.name
            if (selectedLanguage[1] != "en") {
                newNodeText = getBubbleText(node.name ?? "", language: selectedLanguage[1])
            }
            
            // Create a new bubble node text object to display
            let newBubbleNode = createBubbleNode(newNodeText ?? "")
            
            // Replace old node text in the array on the parent node
            node.replaceChildNode(node.childNodes[0], with: newBubbleNode)
        }
    }
    
    // Outlets
    @IBOutlet weak var languageButton: UIButton!
    
    // Scene
    @IBOutlet var sceneView: ARSCNView!
    var latestPrediction : String = ""   // latest CoreML prediction
    let bubbleDepth : Float = 0.02  // 'depth' of 3D text
    
    // CoreML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hqdo.dispatchqueueml")  // a serial queue
    @IBOutlet weak var debugTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize language button
        languageButton.setTitle(selectedLanguage[0], for: UIControl.State.normal)
        
        // Google Translate
        SwiftGoogleTranslate.shared.start(with: Secrets.apiKey)
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting
        sceneView.autoenablesDefaultLighting = true
        
        // Tap Gesture Recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        // Set up Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from https://developer.apple.com/machine-learning/ . Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation")
        }
        
        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        
        // crop from center of image and scale to appropriate size
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        
        visionRequests = [classificationRequest]
        
        // Begin loop to update CoreML
        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // Mark: - CoreML Vision Handling
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get classifications
        let classifications = observations[0...2]   // top 3 results
            .compactMap({$0 as? VNClassificationObservation})
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))"})
            .joined(separator: "\n")
        
        DispatchQueue.main.async {
            
            // Display debug text on screen
            var debugText: String = ""
            debugText += classifications
            self.debugTextView.text = debugText
            
            // Store latest prediction
            var objectName: String = "..."
            objectName = classifications.components(separatedBy: "-")[0]
            objectName = objectName.components(separatedBy: ",")[0]
            self.latestPrediction = objectName
        }
    }
    
    func updateCoreML() {
        // Get camera image as RGB
        let pixBuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixBuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixBuff!)
        // Note: Not entirely sure if the ciImage is being interpreted as RGB, but for now it works with the Inception model.
        // Note2: Also uncertain if the pixelBuffer should be rotated before handing off to Vision (VNImageRequestHandler) - regardless, for now, it still works well with the Inception model.

        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        // let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage!, orientation: myOrientation, options: [:])
        // Alternatively; we can convert the above to an RGB CGImage and use that. Also UIInterfaceOrientation can inform orientation values.
        
        // Run image request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it is ready (preventing hiccups in frame rate)
        
        dispatchQueueML.async {
            // 1. Run update
            self.updateCoreML()
            
            // 2. Loop this function
            self.loopCoreMLUpdate()
        }
    }

    // MARK: - Interaction
    
    // Get text to display
    func getBubbleText(_ text: String, language: String) -> String {
        var bubbleText: String = ""

        // Create text in chosen language
        let asyncGroup = DispatchGroup()
        if (selectedLanguage[1] != "en") {
            asyncGroup.enter()
            SwiftGoogleTranslate.shared.translate(text, language, "en") { (text, error) in
                if let translatedText = text {
                    bubbleText = translatedText
                }
                else {
                    print(error as Any)
                    print("Text not translated")
                }
                asyncGroup.leave()
            }
        }
        else {
            bubbleText = latestPrediction
        }
        asyncGroup.wait()
        return bubbleText
    }
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // HIT TEST : REAL WORLD
        // Get screen center
        let screenCenter : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        
        // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCenter, types: [.featurePoint])
        
        if let closestResult = arHitTestResults.first {
            // Get coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Create text in chosen language
            let bubbleText = getBubbleText(latestPrediction, language: selectedLanguage[1])
            
            // Create 3D Text
            let node : SCNNode = createNewBubbleParentNode(bubbleText)
            node.name = latestPrediction    // keep track of node's original name in English for translation
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord

        }
    }
    
    func createBubbleNode(_ text: String) -> SCNNode {
        // Bubble-Text
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Arial", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.firstMaterial?.diffuse.contents = UIColor.yellow
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // setting bubble.flatness too low can cause crashes
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // Bubble Node
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Center Node - to Center-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        return bubbleNode
    }
    
    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing.
        // To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // Text Billboard Constraint
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // Bubble-Text
        let bubbleNode = createBubbleNode(text)
        
        // Center Point Node
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // Bubble parent node
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        return bubbleNodeParent
    }
    
    // MARK: - Status Bar: Hide
    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptor.SymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
