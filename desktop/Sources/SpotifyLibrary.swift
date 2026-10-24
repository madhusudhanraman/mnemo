import Cocoa
import CryptoKit
import Network
import Security

protocol SpotifyTokenStorage {
    func load() throws -> Data?
    func save(_ data:Data) throws
    func remove() throws
}
struct SpotifyKeychain:SpotifyTokenStorage {
    private var query:[String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"local.mnemo.spotify.library",kSecAttrAccount as String:"oauth"] }
    func load() throws -> Data? {
        var q=query;q[kSecReturnData as String]=true;q[kSecMatchLimit as String]=kSecMatchLimitOne
        var value:CFTypeRef?;let status=SecItemCopyMatching(q as CFDictionary,&value)
        if status==errSecItemNotFound { return nil }
        guard status==errSecSuccess else { throw NSError(domain:NSOSStatusErrorDomain,code:Int(status)) }
        return value as? Data
    }
    func save(_ data:Data) throws {
        let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status==errSecItemNotFound {
            var q=query;q[kSecValueData as String]=data;q[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added=SecItemAdd(q as CFDictionary,nil)
            guard added==errSecSuccess else { throw NSError(domain:NSOSStatusErrorDomain,code:Int(added)) };return
        }
        guard status==errSecSuccess else { throw NSError(domain:NSOSStatusErrorDomain,code:Int(status)) }
    }
    func remove() throws {
        let status=SecItemDelete(query as CFDictionary)
        guard status==errSecSuccess || status==errSecItemNotFound else { throw NSError(domain:NSOSStatusErrorDomain,code:Int(status)) }
    }
}
private final class SpotifyNoRedirect:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) { completionHandler(nil) }
}
final class SpotifyLibrary {
    static let redirect="http://127.0.0.1:8765/callback"
    static let scopes="user-library-read user-library-modify"
    struct Tokens:Codable { var clientID:String;var access:String;var refresh:String;var expires:Double }
    typealias Transport=(URLRequest,@escaping(Data?,HTTPURLResponse?,Error?)->Void)->Void
    private let storage:SpotifyTokenStorage
    private let transport:Transport
    private var tokens:Tokens?
    private var listener:NWListener?
    private var timeout:DispatchWorkItem?
    private var authorization:(state:String,verifier:String,clientID:String)?
    private var epoch=UUID()
    private var refreshing=false
    private var waiters:[(Result<String,Error>)->Void]=[]
    private var reading=Set<String>()
    private var mutating=Set<String>()
    private var cache:[String:(saved:Bool,at:Date)]=[:]
    private var retryAfter=Date.distantPast
    var onChange:(()->Void)?
    var status:String?
    private(set) var connecting=false
    var connected:Bool { tokens != nil }
    var clientID:String { tokens?.clientID ?? "" }
    init(storage:SpotifyTokenStorage=SpotifyKeychain(),transport:Transport?=nil) {
        self.storage=storage
        let configuration=URLSessionConfiguration.ephemeral;configuration.timeoutIntervalForRequest=15;configuration.httpShouldSetCookies=false;configuration.urlCache=nil
        let session=URLSession(configuration:configuration,delegate:SpotifyNoRedirect(),delegateQueue:nil)
        self.transport=transport ?? { request,done in session.dataTask(with:request) { data,response,error in DispatchQueue.main.async { done(data,response as? HTTPURLResponse,error) } }.resume() }
        do { if let data=try storage.load() { tokens=try JSONDecoder().decode(Tokens.self,from:data) } }
        catch { status="Could not read the Spotify connection from Keychain. Connect again." }
    }
    static func validClientID(_ id:String) -> Bool { id.range(of:"^[a-fA-F0-9]{32}$",options:.regularExpression) != nil }
    static func trackURI(_ uri:String) -> Bool { uri.range(of:"^spotify:track:[A-Za-z0-9]{22}$",options:.regularExpression) != nil }
    static func base64URL(_ data:Data) -> String { data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"") }
    private static func random() throws -> String {
        var bytes=[UInt8](repeating:0,count:32)
        guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes)==errSecSuccess else { throw failure("Could not create a secure sign-in request.") }
        return base64URL(Data(bytes))
    }
    static func failure(_ message:String) -> Error { NSError(domain:"MnemoSpotify",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
    static func authorizationURL(clientID:String,state:String,verifier:String) -> URL {
        var url=URLComponents(string:"https://accounts.spotify.com/authorize")!
        url.queryItems=[.init(name:"client_id",value:clientID),.init(name:"response_type",value:"code"),.init(name:"redirect_uri",value:redirect),.init(name:"scope",value:scopes),.init(name:"state",value:state),.init(name:"code_challenge_method",value:"S256"),.init(name:"code_challenge",value:base64URL(Data(SHA256.hash(data:Data(verifier.utf8)))))]
        return url.url!
    }
    func connect(clientID:String) {
        let id=clientID.trimmingCharacters(in:.whitespacesAndNewlines)
        guard Self.validClientID(id) else { status="Enter the Client ID from your Spotify developer app.";onChange?();return }
        epoch=UUID();let pending=waiters;waiters.removeAll();refreshing=false;pending.forEach{$0(.failure(Self.failure("Spotify connection changed.")))}
        cancelAuthorization();connecting=true;status="Opening Spotify sign-in…";onChange?()
        do {
            let state=try Self.random(),verifier=try Self.random();authorization=(state,verifier,id)
            let parameters=NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host:.ipv4(.loopback),port:8765)
            let listener=try NWListener(using:parameters);self.listener=listener
            listener.newConnectionHandler={ [weak self] connection in
                connection.start(queue:.main)
                self?.receive(connection,data:Data())
            }
            listener.stateUpdateHandler={ [weak self] value in
                guard let self=self,self.authorization?.state==state else { return }
                switch value {
                case .ready:
                    if NSWorkspace.shared.open(Self.authorizationURL(clientID:id,state:state,verifier:verifier)) { self.status="Finish signing in to Spotify in your browser.";self.onChange?() }
                    else { self.finishAuthorization(error:"Could not open your browser. Try Connect again.") }
                case .failed: self.finishAuthorization(error:"Could not open the local sign-in callback on port 8765. Try again.")
                default:break
                }
            }
            listener.start(queue:.main)
            let timeout=DispatchWorkItem { [weak self] in self?.finishAuthorization(error:"Spotify sign-in timed out. Try Connect again.") };self.timeout=timeout
            DispatchQueue.main.asyncAfter(deadline:.now()+180,execute:timeout)
        } catch { finishAuthorization(error:error.localizedDescription) }
    }
    private func receive(_ connection:NWConnection,data:Data) {
        connection.receive(minimumIncompleteLength:1,maximumLength:4096) { [weak self] bytes,_,complete,error in
            guard let self=self else { connection.cancel();return }
            var request=data;request.append(bytes ?? Data())
            guard request.count<=8192,error==nil else { connection.cancel();return }
            guard let text=String(data:request,encoding:.utf8),text.contains("\r\n\r\n") else {
                if complete { connection.cancel() } else { self.receive(connection,data:request) };return
            }
            let parts=(text.components(separatedBy:"\r\n").first ?? "").split(separator:" ")
            guard parts.count==3,parts[0]=="GET",let url=URLComponents(string:"http://127.0.0.1:8765"+String(parts[1])),url.path=="/callback",let auth=self.authorization else { self.respond(connection,ok:false);return }
            let values=Dictionary(grouping:url.queryItems ?? [],by:{$0.name})
            guard values["state"]?.count==1,values["state"]?.first?.value==auth.state else { self.respond(connection,ok:false);return }
            if values["error"] != nil { self.respond(connection,ok:true);self.finishAuthorization(error:"Spotify sign-in was cancelled or denied.");return }
            guard values["code"]?.count==1,let code=values["code"]?.first?.value,!code.isEmpty else { self.respond(connection,ok:false);return }
            self.respond(connection,ok:true)
            self.cancelAuthorization();self.connecting=true;self.status="Connecting Spotify…";self.onChange?()
            let epoch=self.epoch
            self.tokenRequest(["grant_type":"authorization_code","code":code,"redirect_uri":Self.redirect,"client_id":auth.clientID,"code_verifier":auth.verifier]) { result in
                guard self.epoch==epoch else { return }
                switch result {
                case .success(let value):
                    do { try self.accept(value,clientID:auth.clientID,oldRefresh:nil);self.finishAuthorization(error:nil) }
                    catch { self.finishAuthorization(error:error.localizedDescription) }
                case .failure(let error): self.finishAuthorization(error:error.localizedDescription)
                }
            }
        }
    }
    private func respond(_ connection:NWConnection,ok:Bool) {
        let body=ok ? "Return to Mnemo. Sign-in is being processed.":"Invalid sign-in callback. Return to Mnemo and try again."
        let response="HTTP/1.1 \(ok ? "200 OK":"400 Bad Request")\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content:Data(response.utf8),completion:.contentProcessed({_ in connection.cancel()}))
    }
    private func cancelAuthorization() { timeout?.cancel();timeout=nil;listener?.cancel();listener=nil;authorization=nil }
    private func finishAuthorization(error:String?) { cancelAuthorization();connecting=false;status=error;onChange?() }
    func disconnect() {
        do { try storage.remove() } catch { status="Could not remove the Spotify connection from Keychain.";onChange?();return }
        epoch=UUID();cancelAuthorization();connecting=false;tokens=nil;cache.removeAll();reading.removeAll();mutating.removeAll();status=nil
        let pending=waiters;waiters.removeAll();refreshing=false;pending.forEach{$0(.failure(Self.failure("Spotify was disconnected.")))};onChange?()
    }
    private func accept(_ value:[String:Any],clientID:String,oldRefresh:String?) throws {
        guard let access=value["access_token"] as? String,let refresh=value["refresh_token"] as? String ?? oldRefresh,let expires=value["expires_in"] as? Double,!access.isEmpty,!refresh.isEmpty else { throw Self.failure("Spotify returned an incomplete connection. Try Connect again.") }
        if let scopes=value["scope"] as? String,!Set(Self.scopes.split(separator:" ")).isSubset(of:Set(scopes.split(separator:" "))) { throw Self.failure("Spotify did not grant library access. Connect again and allow saving songs.") }
        let next=Tokens(clientID:clientID,access:access,refresh:refresh,expires:Date().timeIntervalSince1970+expires-30)
        try storage.save(JSONEncoder().encode(next));tokens=next;cache.removeAll()
    }
    private static func form(_ values:[String:String]) -> Data {
        var parts=URLComponents();parts.queryItems=values.sorted{$0.key<$1.key}.map{URLQueryItem(name:$0.key,value:$0.value)}
        return Data((parts.percentEncodedQuery ?? "").replacingOccurrences(of:"+",with:"%2B").utf8)
    }
    private func tokenRequest(_ values:[String:String],completion:@escaping(Result<[String:Any],Error>)->Void) {
        var request=URLRequest(url:URL(string:"https://accounts.spotify.com/api/token")!);request.httpMethod="POST";request.httpBody=Self.form(values);request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        transport(request) { data,response,error in
            guard error==nil,let data=data,let response=response else { completion(.failure(Self.failure("Could not reach Spotify. Check your connection and try again.")));return }
            guard response.statusCode==200,let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { completion(.failure(Self.failure("Spotify sign-in could not be completed. Check your developer app and reconnect.")));return }
            completion(.success(value))
        }
    }
    private func access(_ completion:@escaping(Result<String,Error>)->Void) {
        guard let tokens=tokens else { completion(.failure(Self.failure("Connect Spotify in Mnemo Settings to save songs.")));return }
        if tokens.expires>Date().timeIntervalSince1970 { completion(.success(tokens.access));return }
        waiters.append(completion);guard !refreshing else { return };refreshing=true
        let epoch=self.epoch
        tokenRequest(["grant_type":"refresh_token","refresh_token":tokens.refresh,"client_id":tokens.clientID]) { result in
            guard self.epoch==epoch else { return }
            self.refreshing=false
            let outcome:Result<String,Error>
            do { let value=try result.get();try self.accept(value,clientID:tokens.clientID,oldRefresh:tokens.refresh);outcome = .success(self.tokens!.access) }
            catch { outcome = .failure(error) }
            let pending=self.waiters;self.waiters.removeAll();pending.forEach{$0(outcome)}
        }
    }
    func saved(_ uri:String) -> Bool? { cache[uri]?.saved }
    func inspect(_ uri:String) {
        guard connected,Self.trackURI(uri),!reading.contains(uri),Date()>=retryAfter else { return }
        if let entry=cache[uri],Date().timeIntervalSince(entry.at)<60 { return }
        reading.insert(uri)
        let epoch=self.epoch
        request(uri:uri,method:"GET",contains:true) { result in
            guard self.epoch==epoch else { return }
            self.reading.remove(uri)
            switch result { case .success(let value):self.cache[uri]=(value,Date());self.status=nil;case .failure(let error):self.status=error.localizedDescription }
            self.onChange?()
        }
    }
    func toggle(_ uri:String,completion:@escaping(String?)->Void) {
        guard Self.trackURI(uri) else { completion("This item cannot be saved as a Spotify song.");return }
        guard !mutating.contains(uri) else { completion("This song is already being updated.");return }
        mutating.insert(uri)
        let epoch=self.epoch
        let finish:(String?)->Void={ error in self.mutating.remove(uri);completion(error) }
        let apply:(Bool)->Void={ current in
            self.request(uri:uri,method:current ? "DELETE":"PUT",contains:false) { result in
                guard self.epoch==epoch else { completion("Spotify connection changed.");return }
                switch result {
                case .success:self.cache[uri]=(!current,Date());self.status=nil;finish(nil)
                case .failure(let error):self.status=error.localizedDescription;finish(error.localizedDescription)
                }
                self.onChange?()
            }
        }
        if let saved=saved(uri) { apply(saved) }
        else { request(uri:uri,method:"GET",contains:true) { result in switch result { case .success(let value):apply(value);case .failure(let error):finish(error.localizedDescription) } } }
    }
    private func request(uri:String,method:String,contains:Bool,retried:Bool=false,completion:@escaping(Result<Bool,Error>)->Void) {
        guard Date()>=retryAfter else { completion(.failure(Self.failure("Spotify asked Mnemo to wait. Try again later.")));return }
        let epoch=self.epoch
        access { token in
            guard self.epoch==epoch else { completion(.failure(Self.failure("Spotify connection changed.")));return }
            switch token {
            case .failure(let error):completion(.failure(error))
            case .success(let token):
                var url=URLComponents(string:"https://api.spotify.com/v1/me/library"+(contains ? "/contains":""))!;url.queryItems=[.init(name:"uris",value:uri)]
                var request=URLRequest(url:url.url!);request.httpMethod=method;request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
                self.transport(request) { data,response,error in
                    guard self.epoch==epoch else { completion(.failure(Self.failure("Spotify connection changed.")));return }
                    guard error==nil,let response=response else { completion(.failure(Self.failure("Could not reach Spotify. Try again.")));return }
                    if response.statusCode==401 && !retried { self.tokens?.expires=0;self.request(uri:uri,method:method,contains:contains,retried:true,completion:completion);return }
                    if response.statusCode==429 {
                        self.retryAfter=Date().addingTimeInterval(max(5,Double(response.value(forHTTPHeaderField:"Retry-After") ?? "60") ?? 60))
                        completion(.failure(Self.failure("Spotify’s request limit was reached. Try again later.")));return
                    }
                    guard (200...299).contains(response.statusCode) else { completion(.failure(Self.failure(response.statusCode==403 ? "Spotify denied library access. Check your developer app’s users and permissions.":"Spotify library access failed. Reconnect in Mnemo Settings.")));return }
                    if contains { guard let data=data,let values=(try? JSONSerialization.jsonObject(with:data)) as? [Bool],let value=values.first else { completion(.failure(Self.failure("Spotify returned an unreadable saved-song status.")));return };completion(.success(value)) }
                    else { completion(.success(true)) }
                }
            }
        }
    }
}
