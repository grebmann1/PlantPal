import Foundation
import Supabase

/// Central Supabase client, configured from cloud config materialized at build time.
enum SupabaseManager {
    static let projectURL = URL(string: "https://jgacczbgxyrysboyyhsj.supabase.co")!
    static let publishableKey = "sb_publishable_aUuUDi7Anr9RdzdzwKpe9g_IpAsYla3"
    static let storageBucket = "plant-photos"

    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: publishableKey
    )
}
