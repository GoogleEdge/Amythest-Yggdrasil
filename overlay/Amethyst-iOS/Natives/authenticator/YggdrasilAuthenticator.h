#import "BaseAuthenticator.h"

@interface YggdrasilAuthenticator : BaseAuthenticator

/// Normalizes an API Root and removes duplicate/trailing slashes.
+ (NSString *)normalizedAPIRoot:(NSString *)raw error:(NSError **)error;

/// Creates a pending external-login account. The password is kept only in memory
/// until login finishes and is never written into authData.
- (instancetype)initWithAPIRoot:(NSString *)apiRoot
                         username:(NSString *)username
                         password:(NSString *)password
             authlibInjectorPath:(NSString *)authlibInjectorPath;

/// Binds the selected profile through /authserver/refresh and saves the account.
- (void)selectProfile:(NSDictionary *)profile callback:(Callback)callback;

@end
