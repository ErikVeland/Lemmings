import Foundation

/**
 * Retains legacy identities for exact owned data after unused DOS drivers are removed.
 */
public enum OwnedContentIdentity {
    /**
     * Maps complete sanitised L2/L3 trees to their original desktop directory revisions.
     * Every other file set keeps its fully hashed revision.
     */
    public static func canonicalDirectoryRevision(raw: String) -> String {
        switch raw {
        case "f789602b5edcce7e19fc545c2f578c9c601eca8c074f4f44e3628f1d389969a0":
            return "0bb7cc6c13d4226d3c039ccc8a90141278a6780258465a14accfe2f8847d51b4"
        case "6fa02e6684b586636f8096a75e890f4324efc13c50ce79bcb6032fde359763e5":
            return "bd15add79b7e121297e584730fead5286335ed54cede3c8e78e473427fc5c41e"
        default: return raw
        }
    }

    /**
     * Maps the same exact sanitised trees under the mobile streaming hash contract.
     */
    public static func canonicalMobileDigest(raw: String) -> String {
        switch raw {
        case "4d6ec1d7cf2af1bf66eb2cc5cfa6bd421d6846f5a4b783e6a04014d64dc2ff64":
            return "10ba02a843ccd754f99059478eb96b9772f5535b615615356b857fc19ff629cc"
        case "e551877aeb3666e7a94d440cece1b97e71edd3096f8ba715a89cbc6366c0996b":
            return "1b1a6a8d750c683a752055f81305949adc4b0eb69020ecfd1940b31f1fd5c60f"
        default: return raw
        }
    }
}
