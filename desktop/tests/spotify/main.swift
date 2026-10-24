import Cocoa
import CryptoKit

func check(_ condition:@autoclosure()->Bool,_ message:String) { if !condition() { fatalError(message) } }
final class MemoryTokens:SpotifyTokenStorage {
    var data:Data?
    init(expired:Bool=false) { data=try! JSONEncoder().encode(SpotifyLibrary.Tokens(clientID:String(repeating:"a",count:32),access:"test-access",refresh:"test-refresh",expires:expired ? 0:Date().timeIntervalSince1970+3600)) }
    func load() throws -> Data? { data }
    func save(_ value:Data) throws { data=value }
    func remove() throws { data=nil }
}
let uri="spotify:track:"+String(repeating:"a",count:22)
let id=String(repeating:"a",count:32)
check(SpotifyLibrary.validClientID(id),"Valid client ID")
check(!SpotifyLibrary.validClientID("secret or malformed"),"Invalid client ID rejected")
check(SpotifyLibrary.trackURI(uri) && !SpotifyLibrary.trackURI("spotify:local:file") && !SpotifyLibrary.trackURI("https://example.com"),"Track-only library access")
let verifier="dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
let auth=URLComponents(url:SpotifyLibrary.authorizationURL(clientID:id,state:"random-state",verifier:verifier),resolvingAgainstBaseURL:false)!
let params=Dictionary(uniqueKeysWithValues:auth.queryItems!.map{($0.name,$0.value!)})
check(params["code_challenge"]=="E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM","RFC 7636 S256 vector")
check(params["state"]=="random-state" && params["redirect_uri"]==SpotifyLibrary.redirect,"State and exact loopback callback")
check(params["scope"]=="user-library-read user-library-modify" && params["client_secret"]==nil,"Only library scopes, no client secret")
var requests=[URLRequest](),wasSaved=false
let storage=MemoryTokens()
let library=SpotifyLibrary(storage:storage,transport:{ request,done in
    requests.append(request)
    check(request.url!.host=="api.spotify.com","Library requests stay on Spotify")
    check(request.value(forHTTPHeaderField:"Authorization")=="Bearer test-access","Access token is sent in header")
    check(URLComponents(url:request.url!,resolvingAgainstBaseURL:false)!.queryItems!.first!.value==uri,"Captured URI sent to library")
    if request.httpMethod=="GET" { done(Data("[\(wasSaved)]".utf8),HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil),nil) }
    else { wasSaved=request.httpMethod=="PUT";done(Data(),HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil),nil) }
})
library.inspect(uri);check(library.saved(uri)==false,"Read liked status")
library.inspect(uri);check(requests.count==1,"Cache avoids duplicate hover reads")
var result:String?="not called"
library.toggle(uri){result=$0};check(result==nil && wasSaved && library.saved(uri)==true,"Save confirmed before heart fills")
library.toggle(uri){result=$0};check(result==nil && !wasSaved && library.saved(uri)==false,"Remove saved song")
check(requests.map{$0.httpMethod!}==["GET","PUT","DELETE"],"Expected library verbs")
library.disconnect();check(storage.data==nil && !library.connected && library.saved(uri)==nil,"Disconnect removes credentials and cached likes")
var tokenRequests=0,apiRequests=0
let refreshed=MemoryTokens(expired:true)
let refreshing=SpotifyLibrary(storage:refreshed,transport:{ request,done in
    if request.url!.host=="accounts.spotify.com" {
        tokenRequests+=1;let body=String(data:request.httpBody!,encoding:.utf8)!
        check(body.contains("grant_type=refresh_token") && !body.contains("client_secret"),"PKCE refresh uses no secret")
        done(Data("{\"access_token\":\"new-access\",\"expires_in\":3600,\"scope\":\"user-library-read user-library-modify\"}".utf8),HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil),nil)
    } else {
        apiRequests+=1;check(request.value(forHTTPHeaderField:"Authorization")=="Bearer new-access","Refreshed token used")
        done(Data("[true]".utf8),HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil),nil)
    }
})
refreshing.inspect(uri);check(tokenRequests==1 && apiRequests==1 && refreshing.saved(uri)==true,"Expired credentials refresh before API access")
var failedCalls=0
let failing=SpotifyLibrary(storage:MemoryTokens(),transport:{ request,done in failedCalls+=1;done(Data(),HTTPURLResponse(url:request.url!,statusCode:429,httpVersion:nil,headerFields:["Retry-After":"60"]),nil) })
failing.toggle(uri){result=$0};check(result != nil && failing.saved(uri)==nil,"Failure never claims saved")
failing.inspect(uri);check(failedCalls==1,"429 backoff stops repeat requests")
print("PASS: PKCE/state/scopes, URI validation, saved-song cache, save/remove, refresh, Keychain abstraction, API failure and rate-limit backoff; no live Spotify requests made")
