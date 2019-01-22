//
//  ViewController.swift
//  ARKitAndCoreML
//
//  Created by HDO on 1/21/19.
//  Copyright © 2019 Henry Do. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    // Scene
    @IBOutlet var sceneView: ARSCNView!
    var latestPrediction : String = "..."   // latest CoreML prediction
    
    // CoreML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hqdo.dispatchqueueml")  // a serial queue
    @IBOutlet weak var debugTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        let classifications = observations[0...1]   // top 2 results
            .compactMap({$0 as? VNClassificationObservation})
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))"})
            .joined(separator: "\n")
        
        DispatchQueue.main.async {
            // print classifications
            print(classifications)
            print("--")
            
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
