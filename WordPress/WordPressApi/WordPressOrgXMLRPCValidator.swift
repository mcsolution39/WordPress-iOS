import Foundation

@objc public enum WordPressOrgXMLRPCValidatorError: Int, ErrorType {
    case EmptyURL // The URL provided was nil, empty or just whitespaces
    case InvalidURL // The URL provided was an invalid URL
    case InvalidScheme // The URL provided was an invalid scheme, only HTTP and HTTPS supported
    case NotWordPressError // That's a XML-RPC endpoint but doesn't look like WordPress
    case MobilePluginRedirectedError // There's some "mobile" plugin redirecting everything to their site
    case Invalid // Doesn't look to be valid XMLRPC Endpoint.

    func convertToNSError() -> NSError {
        let castedError = self as NSError
        let message: String
        switch (self) {
        case .EmptyURL:
            message = NSLocalizedString("Empty URL", comment:"Message to show to user when he tries to add a self-hosted site that is an empty URL.")
        case .InvalidURL:
            message = NSLocalizedString("Invalid URL, please check if you wrote a valid site address.", comment:"Message to show to user when he tries to add a self-hosted site that isn't a valid URL.")
        case .InvalidScheme:
            message = NSLocalizedString("Invalid URL scheme inserted, only HTTP and HTTPS are supported.", comment:"Message to show to user when he tries to add a self-hosted site that isn't HTTP or HTTPS.")
        case .NotWordPressError:
            message = NSLocalizedString("That doesn't look like a WordPress site.", comment: "Message to show to user when he tries to add a self-hosted site that isn't a WordPress site.")
        case .MobilePluginRedirectedError:
            message = NSLocalizedString("You seem to have installed a mobile plugin from DudaMobile which is preventing the app to connect to your blog", comment:"")
        case .Invalid:
            message = NSLocalizedString("That doesn't look like a WordPress site.", comment: "Message to show to user when he tries to add a self-hosted site that isn't a WordPress site.")
        }
        let finalError = NSError(domain: castedError.domain,
                                 code: castedError.code,
                                 userInfo: [NSLocalizedDescriptionKey: message])
        return finalError
    }
}

public class WordPressOrgXMLRPCValidator: NSObject {

    override public init() {
        super.init()
    }

    public func guessXMLRPCURLForSite(site: String,
                                      success: (xmlrpcURL: NSURL) -> (),
                                      failure: (error: NSError) -> ()) {
        let xmlrpcURL: NSURL
        do {
            xmlrpcURL = try urlForXMLRPCFromUrlString(site, addXMLRPC: true)
        } catch let error as NSError {
            DDLogSwift.logError(error.localizedDescription)
            failure(error: error)
            return
        }
        validateXMLRPCUrl(xmlrpcURL, success: { (xmlrpcURL) in
                success(xmlrpcURL: xmlrpcURL)
            }, failure: { (error) in
                DDLogSwift.logError(error.localizedDescription)
                if error.domain == NSURLErrorDomain && error.code == NSURLErrorUserCancelledAuthentication {
                    failure(error: error)
                    return
                }
                // Try the original given url as an XML-RPC endpoint
                let  originalXmlrpcURL = try! self.urlForXMLRPCFromUrlString(site, addXMLRPC:false)
                DDLogSwift.logError("Try the original given url as an XML-RPC endpoint: \(originalXmlrpcURL)")
                self.validateXMLRPCUrl(originalXmlrpcURL , success: { (xmlrpcURL) in
                        success(xmlrpcURL: xmlrpcURL)
                    }, failure: { (error) in
                        DDLogSwift.logError(error.localizedDescription)
                        failure(error: error)
                })
            })
    }

    private func urlForXMLRPCFromUrlString(urlString: String, addXMLRPC: Bool) throws -> NSURL {
        var resultURLString = urlString
        // Is an empty url? Sorry, no psychic powers yet
        resultURLString = urlString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        if resultURLString.isEmpty {
            throw WordPressOrgXMLRPCValidatorError.EmptyURL.convertToNSError()
        }

        // Check if it's a valid URL
        // Not a valid URL. Could be a bad protocol (htpp://), syntax error (http//), ...
        // See https://github.com/koke/NSURL-Guess for extra help cleaning user typed URLs
        guard let baseURL = NSURL(string:resultURLString) else {
            throw WordPressOrgXMLRPCValidatorError.InvalidURL.convertToNSError()
        }

        // Let's see if a scheme is provided and it's HTTP or HTTPS
        var scheme = baseURL.scheme.lowercaseString
        if scheme.isEmpty {
            resultURLString = "http://\(resultURLString)"
            scheme = "http"
        }

        guard scheme == "http" || scheme == "https" else {
            throw WordPressOrgXMLRPCValidatorError.InvalidScheme.convertToNSError()
        }

        if baseURL.lastPathComponent != "xmlrpc.php" && addXMLRPC {
            // Assume the given url is the home page and XML-RPC sits at /xmlrpc.php
            DDLogSwift.logInfo("Assume the given url is the home page and XML-RPC sits at /xmlrpc.php")
            resultURLString = "\(resultURLString)/xmlrpc.php"
        }

        guard let url = NSURL(string: resultURLString) else {
            throw WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError()
        }

        return url
    }

    private func validateXMLRPCUrl(url:NSURL,
                                   success: (xmlrpcURL: NSURL) -> (),
                                   failure: (error: NSError) -> ()) {
        let api = WordPressOrgXMLRPCApi(endpoint: url)
        api.callMethod("system.listMethods", parameters: nil, success: { (responseObject, httpResponse) in
                guard let methods = responseObject as? [String]
                      where methods.contains("wp.getUsersBlogs") else {
                        failure(error:WordPressOrgXMLRPCValidatorError.NotWordPressError.convertToNSError())
                        return
                }
                if let finalURL = httpResponse?.URL {
                    success(xmlrpcURL: finalURL)
                } else {
                    failure(error:WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError())
                }
            }, failure: { (error, httpResponse) in
                failure(error: error)
            })
    }

    private func guessXMLRPCURLFromHTMLURL(htmlURL: NSURL,
                                           success: (xmlrpcURL: NSURL) -> (),
                                           failure: (error: NSError) -> ()) {
        DDLogSwift.logInfo("Fetch the original url and look for the RSD link by using RegExp")
        let session = NSURLSession()
        let dataTask = session.dataTaskWithURL(htmlURL) { (data, response, error) in
            if let error = error {
                failure(error: error)
                return
            }
            guard let data = data,
                  let responseString = NSString(data: data, encoding: NSUTF8StringEncoding),
                  let rsdURLRegExp = try? NSRegularExpression(pattern:"<link\\s+rel=\"EditURI\"\\s+type=\"application/rsd\\+xml\"\\s+title=\"RSD\"\\s+href=\"([^\"]*)\"[^/]*/>", options: [.CaseInsensitive])
            else {
                    failure(error: WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError())
                return
            }

            let matches = rsdURLRegExp.matchesInString(responseString as String, options:NSMatchingOptions(), range:NSMakeRange(0, responseString.length))
            if matches.count <= 0 {
                failure(error: WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError())
                return
            }
            let rsdURLRange = matches[0].rangeAtIndex(1)
            if rsdURLRange.location == NSNotFound {
                failure(error: WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError())
                return
            }
            let rsdURL = responseString.substringWithRange(rsdURLRange)
            // Try removing "?rsd" from the url, it should point to the XML-RPC endpoint
            let xmlrpc = rsdURL.stringByReplacingOccurrencesOfString("?rsd", withString:"")
            if xmlrpc != rsdURL {
                guard let newURL = NSURL(string: xmlrpc) else {
                    failure(error: WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError())
                    return
                }
                self.validateXMLRPCUrl(newURL, success: success, failure: { (error) in
                    //Try to validate by using the RSD file directly
                    failure(error: WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError())
                })
            } else {
                //Try to validate by using the RSD file directly
                failure(error: WordPressOrgXMLRPCValidatorError.Invalid.convertToNSError())
            }
        }
        dataTask.resume()
    }
}
