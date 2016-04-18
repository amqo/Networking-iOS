//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        
        // FIX: As of Swift 2.2, using strings for selectors has been deprecated. Instead, #selector(methodName) should be used.
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.Text: phraseTextField.text,
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]
            
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    private func bboxString(latitude: String, longitude: String) -> String {
        
        guard let latitudeDouble = Double(latitude), let longitudeDouble = Double(longitude) else {
            return "0,0,0,0"
        }
        
        let minimumLon = max(longitudeDouble - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let minimumLat = max(latitudeDouble - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let maximumLon = min(longitudeDouble + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
        let maximumLat = min(latitudeDouble + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        
        return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
    }
    
    @IBAction func searchByLatLon(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) &&
            isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            
            photoTitleLabel.text = "Searching..."
            
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.BoundingBox: bboxString(latitudeTextField.text!, longitude: longitudeTextField.text!),
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]
            
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: flickrURLFromParameters(methodParameters))
        
        let task = session.dataTaskWithRequest(request) {
            (data, response, error) in
            
            func displayError(error: String) {
                print(error)
                performUIUpdatesOnMain() {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No photo returned. Try again."
                    self.photoImageView.image = nil
                }
            }
            
            guard error == nil else {
                displayError(error!.localizedDescription)
                return
            }
            
            print(data!)
            
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String where stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject],
                photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]] else {
                    displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)")
                    return
            }
            
            let randomIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
            let photoDictionary = photoArray[randomIndex] as [String:AnyObject]
            
            guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String,
                photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String else {
                    displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photosDictionary)")
                    return
            }
            
            let imageUrl = NSURL(string: imageUrlString)
            guard let imageData = NSData(contentsOfURL: imageUrl!) else {
                displayError("Cannot get data from url \(imageUrl)")
                return
            }
            
            let photoImage = UIImage(data: imageData)
            performUIUpdatesOnMain() {
                self.photoImageView.image = photoImage
                self.photoTitleLabel.text = photoTitle
                
                self.setUIEnabled(true)
            }
        }
        task.resume()
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}