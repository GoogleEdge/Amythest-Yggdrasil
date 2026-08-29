package net.kdt.pojavlaunch.value;
import net.kdt.pojavlaunch.*;
import java.io.*;
import com.google.gson.*;

public class MinecraftAccount
{
    public String accessToken = "0"; // access token
    public String clientToken = "0"; // clientID: refresh and invalidate
    public String profileId = "00000000-0000-0000-0000-000000000000"; // authenticate UUID
    public String username = "Steve";
    public String xuid;
    public String accountType;
    
    public String save(String outPath) throws IOException {
        Tools.write(outPath, Tools.GLOBAL_GSON.toJson(this));
        return outPath;
    }
    
    public String save() throws IOException {
        return save(Tools.DIR_ACCOUNT_NEW + "/" + username + ".json");
    }
    
    public static MinecraftAccount parse(String content) throws JsonSyntaxException {
        MinecraftAccount account = Tools.GLOBAL_GSON.fromJson(content, MinecraftAccount.class);
        if (account == null) {
            return null;
        }
        // A non-empty token written explicitly in the account JSON is a
        // deliberate Yggdrasil/external-account value. Preserve the existing
        // Microsoft behavior for accounts without an inline token.
        boolean isYggdrasil = "yggdrasil".equals(account.accountType);
        if (!isYggdrasil && account.xuid != null &&
            !account.xuid.trim().isEmpty() && !"0".equals(account.xuid.trim())) {
            String keychainToken = getAccessTokenFromKeychain(account.xuid);
            if (hasTokenValue(keychainToken)) {
                account.accessToken = keychainToken;
            }
        }
        return account;
    }

    private static boolean hasTokenValue(String value) {
        return value != null && !value.trim().isEmpty() && !"0".equals(value.trim());
    }
    
    public static MinecraftAccount load(String name) throws IOException, JsonSyntaxException {
        MinecraftAccount acc = parse(Tools.read(Tools.DIR_ACCOUNT_NEW + "/" + name + ".json"));
        if (acc.accessToken == null) {
            acc.accessToken = "0";
        } if (acc.clientToken == null) {
            acc.clientToken = "0";
        } if (acc.profileId == null) {
            acc.profileId = "0";
        } if (acc.username == null) {
            acc.username = "0";
        } if (acc.xuid == null) {
            acc.xuid = "0";
        }
        return acc;
    }

    static {
        System.loadLibrary("AmethystAccountJNI");
    }
    public static native String getAccessTokenFromKeychain(String xuid);
}
