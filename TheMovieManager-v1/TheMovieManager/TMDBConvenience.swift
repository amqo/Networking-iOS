//
//  TMDBConvenience.swift
//  TheMovieManager
//
//  Created by Jarrod Parkes on 2/11/15.
//  Copyright (c) 2015 Jarrod Parkes. All rights reserved.
//

import UIKit
import Foundation

import PromiseKit


// MARK: - TMDBClient (Convenient Resource Methods)

extension TMDBClient {
    
    // MARK: Authentication (GET) Methods
    /*
        Steps for Authentication...
        https://www.themoviedb.org/documentation/api/sessions
        
        Step 1: Create a new request token
        Step 2a: Ask the user for permission via the website
        Step 3: Create a session ID
        Bonus Step: Go ahead and get the user id 😄!
    */
    func authenticateWithViewController(hostViewController: UIViewController, completionHandlerForAuth: (success: Bool, errorString: String?) -> Void) {
        
        getRequestToken().then { requestToken -> Void in
                
            // success! we have the requestToken!
            print("Request Token: \(requestToken)")
            self.requestToken = requestToken
            
        }.then {
            
            self.loginWithToken(self.requestToken, hostViewController: hostViewController) { (success, errorString) in
                
                if success {
                    self.getSessionID().then { sessionID -> Void in
                        
                        // success! we have the sessionID!
                        self.sessionID = sessionID
                    }.then {
                        return self.getUserID()
                    }.then { userID -> Void in
                        // and the userID 😄!
                        self.userID = userID
                        
                        completionHandlerForAuth(success: success, errorString: errorString)
                        
                    }.error { error -> Void in
                        print(error)
                    }
                } else {
                    completionHandlerForAuth(success: success, errorString: errorString)
                }
            }

            
        }.error { error -> Void in
            print(error)
        }
    }
    
    private func getRequestToken() -> Promise<String> {
        
        /* 1. Specify parameters, the API method, and the HTTP body (if POST) */
        /* 2. Make the request */
        /* 3. Send the desired value(s) to completion handler */
        
        let parameters = [String:AnyObject]()
        
        return Promise { fulfill, reject in
            taskForGETMethod(TMDBClient.Methods.AuthenticationTokenNew, parameters: parameters) { (result, error) in
                if (error != nil) {
                    reject(error!)
                } else {
                    guard let requestToken = result[TMDBClient.JSONResponseKeys.RequestToken] as? String else {
                        let userInfo = [NSLocalizedDescriptionKey : "Cannot find key '\(TMDBClient.JSONResponseKeys.RequestToken)' in \(result)"]
                        let error = NSError(domain: "getRequestToken parsing", code: 0, userInfo: userInfo)
                        reject(error)
                        return
                    }
                    fulfill(requestToken)
                }
            }
        }
    }
    
    private func loginWithToken(requestToken: String?, hostViewController: UIViewController, completionHandlerForLogin: (success: Bool, errorString: String?) -> Void) {
        
        let authorizationURL = NSURL(string: "\(TMDBClient.Constants.AuthorizationURL)\(requestToken!)")
        let request = NSURLRequest(URL: authorizationURL!)
        let webAuthViewController = hostViewController.storyboard!.instantiateViewControllerWithIdentifier("TMDBAuthViewController") as! TMDBAuthViewController
        webAuthViewController.urlRequest = request
        webAuthViewController.requestToken = requestToken
        webAuthViewController.completionHandlerForView = completionHandlerForLogin
        
        let webAuthNavigationController = UINavigationController()
        webAuthNavigationController.pushViewController(webAuthViewController, animated: false)
        
        performUIUpdatesOnMain {
            hostViewController.presentViewController(webAuthNavigationController, animated: true, completion: nil)
        }
    }
    
    private func getSessionID() -> Promise<String> {
        
        let parameters = [TMDBClient.ParameterKeys.RequestToken: requestToken!]
        
        return Promise { fulfill, reject in
        
            taskForGETMethod(TMDBClient.Methods.AuthenticationSessionNew, parameters: parameters) { (result, error) in
                if (error != nil) {
                    reject(error!)
                } else {
                    guard let sessionID = result[TMDBClient.JSONResponseKeys.SessionID] as? String else {
                        let userInfo = [NSLocalizedDescriptionKey : "Cannot find key '\(TMDBClient.JSONResponseKeys.SessionID)' in \(result)"]
                        let error = NSError(domain: "getSessionID parsing", code: 0, userInfo: userInfo)
                        reject(error)
                        return
                    }
                    fulfill(sessionID)
                }
            }
        }
    }
    
    private func getUserID() -> Promise<Int> {
        
        let parameters = [TMDBClient.ParameterKeys.SessionID: sessionID!]
    
        return Promise { fulfill, reject in
        
            taskForGETMethod(TMDBClient.Methods.Account, parameters: parameters) { (result, error) in
                if (error != nil) {
                    reject(error!)
                } else {
                    guard let userID = result[TMDBClient.JSONResponseKeys.UserID] as? Int else {
                        let userInfo = [NSLocalizedDescriptionKey : "Cannot find key '\(TMDBClient.JSONResponseKeys.UserID)' in \(result)"]
                        let error = NSError(domain: "getSessionID parsing", code: 0, userInfo: userInfo)
                        reject(error)
                        return
                    }
                    fulfill(userID)
                }
            }
        }
    }
    
    // MARK: GET Convenience Methods
    
    func getFavoriteMovies(completionHandlerForFavMovies: (result: [TMDBMovie]?, error: NSError?) -> Void) {
        
        let parameters: [String: AnyObject!] = [TMDBClient.ParameterKeys.SessionID: sessionID]
        
        let method = subtituteKeyInMethod(TMDBClient.Methods.AccountIDFavoriteMovies, key: TMDBClient.JSONResponseKeys.UserID, value: "\(self.userID!)")
        
        taskForGETMethod(method!, parameters: parameters) { (result, error) in
            if (error != nil) {
                completionHandlerForFavMovies(result: nil, error: error)
            } else {
                guard let results = result[TMDBClient.JSONResponseKeys.MovieResults] as? [[String: AnyObject]] else {
                    let userInfo = [NSLocalizedDescriptionKey : "Could not parse getFavoriteMovies"]
                    let error = NSError(domain: "getFavoriteMovies parsing", code: 0, userInfo: userInfo)
                    completionHandlerForFavMovies(result: nil, error: error)
                    return
                }
                completionHandlerForFavMovies(result: TMDBMovie.moviesFromResults(results), error: nil)
            }
        }
        
    }
    
    func getWatchlistMovies(completionHandlerForWatchlist: (result: [TMDBMovie]?, error: NSError?) -> Void) {
        
        let parameters: [String: AnyObject!] = [TMDBClient.ParameterKeys.SessionID: sessionID]
        
        let method = subtituteKeyInMethod(TMDBClient.Methods.AccountIDWatchlistMovies, key: TMDBClient.JSONResponseKeys.UserID, value: "\(self.userID!)")
        
        taskForGETMethod(method!, parameters: parameters) { (result, error) in
            if (error != nil) {
                completionHandlerForWatchlist(result: nil, error: error)
            } else {
                guard let results = result[TMDBClient.JSONResponseKeys.MovieResults] as? [[String: AnyObject]] else {
                    let userInfo = [NSLocalizedDescriptionKey : "Could not parse getWatchlistMovies"]
                    let error = NSError(domain: "getWatchlistMovies parsing", code: 0, userInfo: userInfo)
                    completionHandlerForWatchlist(result: nil, error: error)
                    return
                }
                completionHandlerForWatchlist(result: TMDBMovie.moviesFromResults(results), error: nil)
            }
        }
    }
    
    func getMoviesForSearchString(searchString: String, completionHandlerForMovies: (result: [TMDBMovie]?, error: NSError?) -> Void) -> NSURLSessionDataTask? {
        
        let parameters = [TMDBClient.ParameterKeys.Query: searchString]
        
        let task = taskForGETMethod(TMDBClient.Methods.SearchMovie, parameters: parameters) { (result, error) in
            if (error != nil) {
                completionHandlerForMovies(result: nil, error: error)
            } else {
                guard let results = result[TMDBClient.JSONResponseKeys.MovieResults] as? [[String: AnyObject]] else {
                    let userInfo = [NSLocalizedDescriptionKey : "Cannot find key '\(TMDBClient.JSONResponseKeys.MovieResults)' in \(result)"]
                    let error = NSError(domain: "getMoviesForSearchString", code: 1, userInfo: userInfo)
                    completionHandlerForMovies(result: nil, error: error)
                    return
                }
                completionHandlerForMovies(result: TMDBMovie.moviesFromResults(results), error: nil)
            }
        }
        return task
    }
    
    func getConfig(completionHandlerForConfig: (didSucceed: Bool, error: NSError?) -> Void) {
        
        /* 1. Specify parameters, method (if has {key}), and HTTP body (if POST) */
        let parameters = [String:AnyObject]()
        
        /* 2. Make the request */
        taskForGETMethod(Methods.Config, parameters: parameters) { (results, error) in
            
            /* 3. Send the desired value(s) to completion handler */
            if let error = error {
                completionHandlerForConfig(didSucceed: false, error: error)
            } else if let newConfig = TMDBConfig(dictionary: results as! [String:AnyObject]) {
                self.config = newConfig
                completionHandlerForConfig(didSucceed: true, error: nil)
            } else {
                completionHandlerForConfig(didSucceed: false, error: NSError(domain: "getConfig parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse getConfig"]))
            }
        }

    }
    
    // MARK: POST Convenience Methods
    
    func postToFavorites(movie: TMDBMovie, favorite: Bool, completionHandlerForFavorite: (result: Int?, error: NSError?) -> Void)  {
        
        /* 1. Specify parameters, method (if has {key}), and HTTP body (if POST) */
        let parameters = [TMDBClient.ParameterKeys.SessionID : TMDBClient.sharedInstance().sessionID!]
        var mutableMethod: String = Methods.AccountIDFavorite
        mutableMethod = subtituteKeyInMethod(mutableMethod, key: TMDBClient.URLKeys.UserID, value: String(TMDBClient.sharedInstance().userID!))!
        let jsonBody = "{\"\(TMDBClient.JSONBodyKeys.MediaType)\": \"movie\",\"\(TMDBClient.JSONBodyKeys.MediaID)\": \"\(movie.id)\",\"\(TMDBClient.JSONBodyKeys.Favorite)\": \(favorite)}"
        
        /* 2. Make the request */
        taskForPOSTMethod(mutableMethod, parameters: parameters, jsonBody: jsonBody) { (results, error) in
            
            /* 3. Send the desired value(s) to completion handler */
            if let error = error {
                completionHandlerForFavorite(result: nil, error: error)
            } else {
                if let results = results[TMDBClient.JSONResponseKeys.StatusCode] as? Int {
                    completionHandlerForFavorite(result: results, error: nil)
                } else {
                    completionHandlerForFavorite(result: nil, error: NSError(domain: "postToFavoritesList parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse postToFavoritesList"]))
                }
            }
        }
    }
    
    func postToWatchlist(movie: TMDBMovie, watchlist: Bool, completionHandlerForWatchlist: (result: Int?, error: NSError?) -> Void) {
        
        /* 1. Specify parameters, method (if has {key}), and HTTP body (if POST) */
        let parameters = [TMDBClient.ParameterKeys.SessionID : TMDBClient.sharedInstance().sessionID!]
        var mutableMethod: String = Methods.AccountIDWatchlist
        mutableMethod = subtituteKeyInMethod(mutableMethod, key: TMDBClient.URLKeys.UserID, value: String(TMDBClient.sharedInstance().userID!))!
        let jsonBody = "{\"\(TMDBClient.JSONBodyKeys.MediaType)\": \"movie\",\"\(TMDBClient.JSONBodyKeys.MediaID)\": \"\(movie.id)\",\"\(TMDBClient.JSONBodyKeys.Watchlist)\": \(watchlist)}"
        
        /* 2. Make the request */
        taskForPOSTMethod(mutableMethod, parameters: parameters, jsonBody: jsonBody) { (results, error) in
            
            /* 3. Send the desired value(s) to completion handler */
            if let error = error {
                completionHandlerForWatchlist(result: nil, error: error)
            } else {
                if let results = results[TMDBClient.JSONResponseKeys.StatusCode] as? Int {
                    completionHandlerForWatchlist(result: results, error: nil)
                } else {
                    completionHandlerForWatchlist(result: nil, error: NSError(domain: "postToWatchlist parsing", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse postToWatchlist"]))
                }
            }
        }
        
    }
}