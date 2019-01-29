# AugmentedObjectLabeler

### Identify objects using Core ML and label them in AR with ARKit
![gif of augmented reality labels being added to objects](Public/augmentedReality01.gif)

Uses a pretrained machine learning model that attempts to identify object depicted in a picture.

### Labels can be created in various languages via Google translate APIs
![gif of augmented reality labels being translated to other languages via popover pickerview selector](Public/augmentedReality02.gif)

Switching languages changes the language of all currently displayed labels

Based on ARKit and CoreML implementation by Hanley Weng: https://github.com/hanleyweng/CoreML-in-ARKit

Also uses SwiftGoogleTranslate : https://github.com/maximbilan/SwiftGoogleTranslate

### Bugs

Image recognition is inconsistent, though often hilariously so:

![png of cat being mistaken for a doormat](Public/doormat.png)
