//
//  ViewController.swift
//  ImageRequest
//
//  Created by Jarrod Parkes on 11/3/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {

    // MARK: Outlets
    
    @IBOutlet weak var imageView: UIImageView!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let imageUrl = NSURL(string: "https://www.petfinder.com/wp-content/uploads/2012/11/86525557-general-cat-care-632x475.jpg")!
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(imageUrl)
            {(data, response, error) in
                if error == nil {
                    let downloadedImage = UIImage(data: data!)
                    performUIUpdatesOnMain {
                        self.imageView.image = downloadedImage
                    }
                }
        }
    
        task.resume()
    }
}
