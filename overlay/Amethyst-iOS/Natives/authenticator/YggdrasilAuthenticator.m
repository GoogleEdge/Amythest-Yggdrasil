#import "YggdrasilAuthenticator.h"
#import "AFNetworking.h"
#import "../utils.h"

static NSString * const YggdrasilAccountType = @"yggdrasil";

static NSError *YggdrasilError(NSString *message) {
    return [NSError errorWithDomain:@"Amethyst.Yggdrasil" code:1 userInfo:@{
        NSLocalizedDescriptionKey: message ?: @"Yggdrasil 请求失败"
    }];
}

static NSString *YggdrasilString(id value) {
    return [value isKindOfClass:NSString.class] ? value : @"";
}

static NSError *YggdrasilNetworkError(NSError *underlying) {
    NSString *message = underlying.localizedDescription ?: @"网络请求失败";
    NSHTTPURLResponse *httpResponse = underlying.userInfo[AFNetworkingOperationFailingURLResponseErrorKey];
    NSData *body = underlying.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
    if (body.length > 0) {
        id object = [NSJSONSerialization JSONObjectWithData:body options:kNilOptions error:nil];
        if ([object isKindOfClass:NSDictionary.class]) {
            NSMutableArray *parts = [NSMutableArray array];
            for (NSString *key in @[@"error", @"errorMessage", @"cause"]) {
                NSString *part = YggdrasilString(object[key]);
                if (part.length > 0) [parts addObject:part];
            }
            if (parts.count > 0) message = [parts componentsJoinedByString:@"："];
        } else if ([object isKindOfClass:NSString.class] && [object length] > 0) {
            message = object;
        }
    }
    if (httpResponse.statusCode > 0) {
        message = [NSString stringWithFormat:@"HTTP %ld：%@", (long)httpResponse.statusCode, message];
    }
    return YggdrasilError(message);
}

static BOOL YggdrasilIsHex(NSString *value) {
    if (value.length == 0) return NO;
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    return [value rangeOfCharacterFromSet:nonHex].location == NSNotFound;
}

static NSString *YggdrasilHyphenatedUUID(NSString *raw) {
    return [NSString stringWithFormat:@"%@-%@-%@-%@-%@",
        [raw substringWithRange:NSMakeRange(0, 8)],
        [raw substringWithRange:NSMakeRange(8, 4)],
        [raw substringWithRange:NSMakeRange(12, 4)],
        [raw substringWithRange:NSMakeRange(16, 4)],
        [raw substringWithRange:NSMakeRange(20, 12)]];
}

static NSDictionary *YggdrasilNormalizeProfile(id object, NSError **error) {
    if (![object isKindOfClass:NSDictionary.class]) {
        if (error) *error = YggdrasilError(@"角色对象格式错误。");
        return nil;
    }

    NSString *name = [YggdrasilString(object[@"name"]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *identifier = [YggdrasilString(object[@"id"]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length == 0 || identifier.length == 0) {
        if (error) *error = YggdrasilError(@"角色缺少 name 或 id。");
        return nil;
    }

    NSString *raw = [identifier stringByReplacingOccurrencesOfString:@"-" withString:@""];
    BOOL dashed = identifier.length == 36 &&
        [identifier characterAtIndex:8] == '-' &&
        [identifier characterAtIndex:13] == '-' &&
        [identifier characterAtIndex:18] == '-' &&
        [identifier characterAtIndex:23] == '-';
    if (!((identifier.length == 32 || dashed) && raw.length == 32 && YggdrasilIsHex(raw))) {
        if (error) *error = YggdrasilError(@"角色 UUID 格式错误：必须是 32 位十六进制 UUID。");
        return nil;
    }

    raw = raw.lowercaseString;
    return @{
        @"id": raw,
        @"profileId": YggdrasilHyphenatedUUID(raw),
        @"name": name
    };
}

@interface YggdrasilAuthenticator ()

@property(nonatomic, copy) NSString *pendingPassword;
@property(nonatomic, copy) NSString *pendingUsername;
@property(nonatomic, copy) NSString *pendingAPIRoot;
@property(nonatomic, copy) NSString *pendingAuthlibInjectorPath;

- (void)saveProfile:(NSDictionary *)profile
        accessToken:(NSString *)accessToken
       clientToken:(NSString *)clientToken
          callback:(Callback)callback;

@end

@implementation YggdrasilAuthenticator

+ (NSString *)normalizedAPIRoot:(NSString *)raw error:(NSError **)error {
    NSString *value = [raw ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length == 0) {
        if (error) *error = YggdrasilError(@"Yggdrasil API 地址为空。");
        return nil;
    }
    if (![value containsString:@"://"]) value = [@"https://" stringByAppendingString:value];

    NSURLComponents *components = [NSURLComponents componentsWithString:value];
    if (components == nil || components.host.length == 0 || components.user.length > 0 || components.password.length > 0) {
        if (error) *error = YggdrasilError(@"Yggdrasil API 地址格式错误，请检查协议、域名和路径。");
        return nil;
    }
    if (![components.scheme.lowercaseString isEqualToString:@"https"] &&
        ![components.scheme.lowercaseString isEqualToString:@"http"]) {
        if (error) *error = YggdrasilError(@"Yggdrasil API 只支持 HTTP 或 HTTPS。");
        return nil;
    }

    NSString *path = components.path ?: @"";
    while ([path containsString:@"//"]) path = [path stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    while ([path hasSuffix:@"/"]) path = [path substringToIndex:path.length - 1];
    components.path = path;
    components.query = nil;
    components.fragment = nil;

    NSString *normalized = components.URL.absoluteString;
    if (normalized.length == 0) {
        if (error) *error = YggdrasilError(@"Yggdrasil API 地址无法解析。");
        return nil;
    }
    while ([normalized hasSuffix:@"/"]) normalized = [normalized substringToIndex:normalized.length - 1];
    return normalized;
}

- (instancetype)initWithAPIRoot:(NSString *)apiRoot
                         username:(NSString *)username
                         password:(NSString *)password
             authlibInjectorPath:(NSString *)authlibInjectorPath {
    self = [super init];
    if (self) {
        self.authData = [NSMutableDictionary dictionaryWithDictionary:@{
            @"accountType": YggdrasilAccountType,
            @"apiRoot": apiRoot ?: @"",
            @"username": username ?: @"",
            @"expiresAt": @0
        }];
        self.pendingAPIRoot = apiRoot;
        self.pendingUsername = username;
        self.pendingPassword = password;
        self.pendingAuthlibInjectorPath = authlibInjectorPath;
    }
    return self;
}

- (NSString *)endpoint:(NSString *)path {
    NSString *cleanPath = [path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [NSString stringWithFormat:@"%@/%@", self.authData[@"apiRoot"], cleanPath];
}

- (void)loginWithCallback:(Callback)callback {
    NSString *apiRoot = self.pendingAPIRoot ?: self.authData[@"apiRoot"];
    NSString *username = self.pendingUsername ?: self.authData[@"username"];
    NSString *password = self.pendingPassword;
    if (apiRoot.length == 0 || username.length == 0 || password.length == 0) {
        callback(YggdrasilError(@"Yggdrasil 登录信息不完整。"), NO);
        self.pendingPassword = nil;
        return;
    }

    callback(localize(@"login.yggdrasil.progress.authenticate", nil), YES);
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    manager.responseSerializer = AFJSONResponseSerializer.serializer;
    NSDictionary *body = @{
        @"agent": @{
            @"name": @"Minecraft",
            @"version": @1
        },
        @"username": username,
        @"password": password,
        @"requestUser": @YES
    };

    [manager POST:[self endpoint:@"authserver/authenticate"] parameters:body headers:nil progress:nil success:^(NSURLSessionDataTask *task, id response) {
        self.pendingPassword = nil;
        if (![response isKindOfClass:NSDictionary.class]) {
            callback(YggdrasilError(@"authenticate 返回格式错误：不是 JSON 对象。"), NO);
            return;
        }

        NSString *accessToken = [YggdrasilString(response[@"accessToken"]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (accessToken.length == 0) {
            callback(YggdrasilError(@"authenticate 返回格式错误：缺少 accessToken。"), NO);
            return;
        }

        NSString *clientToken = [YggdrasilString(response[@"clientToken"]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        self.authData[@"accessToken"] = accessToken;
        self.authData[@"clientToken"] = clientToken;

        NSMutableArray *profiles = [NSMutableArray array];
        NSArray *availableProfiles = [response[@"availableProfiles"] isKindOfClass:NSArray.class] ? response[@"availableProfiles"] : @[];
        for (id item in availableProfiles) {
            NSError *profileError = nil;
            NSDictionary *profile = YggdrasilNormalizeProfile(item, &profileError);
            if (profile) [profiles addObject:profile];
        }

        NSError *selectedError = nil;
        NSDictionary *selected = response[@"selectedProfile"] ? YggdrasilNormalizeProfile(response[@"selectedProfile"], &selectedError) : nil;
        if (selectedError != nil) {
            callback(selectedError, NO);
            return;
        }
        if (selected && ![profiles containsObject:selected]) [profiles insertObject:selected atIndex:0];

        if (selected) {
            [self saveProfile:selected accessToken:accessToken clientToken:clientToken callback:callback];
        } else if (profiles.count == 1) {
            [self selectProfile:profiles.firstObject callback:callback];
        } else if (profiles.count > 1) {
            // The caller presents a native role picker, then invokes selectProfile:.
            callback(profiles, YES);
        } else {
            callback(YggdrasilError(@"登录成功但没有可用角色：availableProfiles 为空。"), NO);
        }
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        self.pendingPassword = nil;
        callback(YggdrasilNetworkError(error), NO);
    }];
}

- (void)selectProfile:(NSDictionary *)profile callback:(Callback)callback {
    NSString *profileId = YggdrasilString(profile[@"id"]);
    NSString *name = YggdrasilString(profile[@"name"]);
    NSString *accessToken = YggdrasilString(self.authData[@"accessToken"]);
    NSString *clientToken = YggdrasilString(self.authData[@"clientToken"]);
    if (profileId.length == 0 || name.length == 0) {
        callback(YggdrasilError(@"角色选择失败：角色缺少 id 或 name。"), NO);
        return;
    }
    if (accessToken.length == 0 || clientToken.length == 0) {
        callback(YggdrasilError(@"服务器未返回 clientToken，无法通过 /authserver/refresh 绑定角色。"), NO);
        return;
    }

    callback(localize(@"login.yggdrasil.progress.refresh", nil), YES);
    AFHTTPSessionManager *manager = AFHTTPSessionManager.manager;
    manager.requestSerializer = AFJSONRequestSerializer.serializer;
    manager.responseSerializer = AFJSONResponseSerializer.serializer;
    NSDictionary *body = @{
        @"accessToken": accessToken,
        @"clientToken": clientToken,
        @"selectedProfile": @{
            @"id": profileId,
            @"name": name
        },
        @"requestUser": @YES
    };

    [manager POST:[self endpoint:@"authserver/refresh"] parameters:body headers:nil progress:nil success:^(NSURLSessionDataTask *task, id response) {
        if (![response isKindOfClass:NSDictionary.class]) {
            callback(YggdrasilError(@"refresh 返回格式错误：不是 JSON 对象。"), NO);
            return;
        }
        NSString *newToken = [YggdrasilString(response[@"accessToken"]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (newToken.length == 0) {
            callback(YggdrasilError(@"refresh 返回格式错误：缺少 accessToken。"), NO);
            return;
        }
        NSError *profileError = nil;
        NSDictionary *refreshedProfile = response[@"selectedProfile"] ? YggdrasilNormalizeProfile(response[@"selectedProfile"], &profileError) : nil;
        if (profileError != nil) {
            callback(profileError, NO);
            return;
        }
        NSString *newClientToken = YggdrasilString(response[@"clientToken"]);
        [self saveProfile:(refreshedProfile ?: profile)
              accessToken:newToken
             clientToken:(newClientToken.length ? newClientToken : clientToken)
                callback:callback];
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        callback(YggdrasilNetworkError(error), NO);
    }];
}

- (void)saveProfile:(NSDictionary *)profile accessToken:(NSString *)accessToken clientToken:(NSString *)clientToken callback:(Callback)callback {
    NSString *raw = YggdrasilString(profile[@"id"]);
    NSString *profileId = YggdrasilString(profile[@"profileId"]);
    NSString *name = YggdrasilString(profile[@"name"]);
    if (profileId.length == 0 && raw.length == 32 && YggdrasilIsHex(raw)) {
        profileId = YggdrasilHyphenatedUUID(raw.lowercaseString);
    }
    if (raw.length == 0 || profileId.length == 0 || name.length == 0) {
        callback(YggdrasilError(@"角色资料格式错误，无法保存账户。"), NO);
        return;
    }

    self.authData[@"accountType"] = YggdrasilAccountType;
    self.authData[@"apiRoot"] = self.pendingAPIRoot ?: self.authData[@"apiRoot"] ?: @"";
    self.authData[@"accessToken"] = accessToken ?: @"";
    self.authData[@"clientToken"] = clientToken ?: @"";
    self.authData[@"profileId"] = profileId;
    self.authData[@"username"] = name;
    self.authData[@"profilePicURL"] = [NSString stringWithFormat:@"https://mc-heads.net/head/%@/120", raw];
    NSURLComponents *apiComponents = [NSURLComponents componentsWithString:self.authData[@"apiRoot"]];
    if (apiComponents.host.length > 0) {
        self.authData[@"serverName"] = apiComponents.host;
    }
    self.authData[@"expiresAt"] = @0;
    if (self.pendingAuthlibInjectorPath.length > 0) {
        self.authData[@"authlibInjectorPath"] = self.pendingAuthlibInjectorPath;
    } else {
        [self.authData removeObjectForKey:@"authlibInjectorPath"];
    }
    [self.authData removeObjectsForKeys:@[@"input", @"inputPassword", @"oldusername", @"msaRefreshToken", @"xuid", @"xboxGamertag"]];

    if ([self saveChanges]) {
        BaseAuthenticator.current = self;
        callback(nil, YES);
    } else {
        callback(YggdrasilError(@"无法写入 Amethyst 账户文件。"), NO);
    }
}

- (void)refreshTokenWithCallback:(Callback)callback {
    // Yggdrasil servers do not expose a common expiry field. Keep the saved
    // token and let a future explicit login obtain a new one.
    callback(nil, YES);
}

@end
