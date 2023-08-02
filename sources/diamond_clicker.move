module diamond_clicker::game {
    use std::signer;
    use std::vector;

    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    /*
    Errors
    DO NOT EDIT
    */
    const ERROR_GAME_STORE_DOES_NOT_EXIST: u64 = 0;
    const ERROR_UPGRADE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE: u64 = 2;

    /*
    Const
    DO NOT EDIT
    */
    const POWERUP_NAMES: vector<vector<u8>> = vector[b"Bruh", b"Aptomingos", b"Aptos Monkeys"];
    // cost, dpm (diamonds per minute)
    const POWERUP_VALUES: vector<vector<u64>> = vector[
        vector[5, 5],
        vector[25, 30],
        vector[250, 350],
    ];

    /*
    Structs
    DO NOT EDIT
    */
    struct Upgrade has key, store, copy {
        name: vector<u8>,
        amount: u64
    }

    struct GameStore has key {
        diamonds: u64,
        upgrades: vector<Upgrade>,
        last_claimed_timestamp_seconds: u64,
    }

    /*
    Functions
    */

    public fun initialize_game(account: &signer) {
        let new_game_store:GameStore=GameStore{
            diamonds: 0,
            upgrades: vector<Upgrade>(),
            last_claimed_timestamp_seconds:0,
        };
        move_to(account,new_game_store)
    }

    public entry fun click(account: &signer) acquires GameStore {
        if (!exists<GameStore>(account)) {
        initialize_game(account);
        }

        move_to<GameStore>(account).diamonds += 1;
    }

    fun get_unclaimed_diamonds(account_address: address, current_timestamp_seconds: u64): u64 acquires GameStore {
    // Acquire the GameStore for the given account_address
    let game_store = borrow_global<GameStore>(account_address);

    // Initialize the variable to store the total unclaimed diamonds
    var unclaimed_diamonds: u64 = 0;

    // Loop over game_store.upgrades to calculate unclaimed diamonds from each power-up
    for (let i: u64 = 0; i < game_store.upgrades.length; i++) {
        let powerup = game_store.upgrades[i];
        let powerup_index = i as usize;

        // Check if the powerup_index is within the range of POWERUP_VALUES vector
        if (powerup_index < POWERUP_VALUES.length) {
            let powerup_cost = POWERUP_VALUES[powerup_index][0];
            let powerup_dpm = POWERUP_VALUES[powerup_index][1];

            // Calculate the time elapsed since the last claimed timestamp in minutes
            let minutes_elapsed = (current_timestamp_seconds - game_store.last_claimed_timestamp_seconds) / 60;

            // Calculate the unclaimed diamonds from this power-up
            let powerup_unclaimed_diamonds = powerup.amount * powerup_dpm * minutes_elapsed;

            // Add the unclaimed diamonds from this power-up to the total unclaimed diamonds
            unclaimed_diamonds += powerup_unclaimed_diamonds;
        }
    }

    // Return the total unclaimed diamonds
    return unclaimed_diamonds;
}


    fun claim(account_address: address) acquires GameStore {
    // Acquire the GameStore for the given account_address
    let game_store = move_from<GameStore>(account_address);

    // Calculate the unclaimed diamonds using get_unclaimed_diamonds function
    let unclaimed_diamonds = get_unclaimed_diamonds(account_address, timestamp::get_time());

    // Set game_store.diamonds to current diamonds + unclaimed_diamonds
    game_store.diamonds += unclaimed_diamonds;

    // Set last_claimed_timestamp_seconds to the current timestamp in seconds
    game_store.last_claimed_timestamp_seconds = timestamp::get_time();

    // Move the updated GameStore back to the Global Storage
    move_to(account_address, game_store);
}
 +

    public entry fun upgrade(account: &signer, upgrade_index: u64, upgrade_amount: u64) acquires GameStore {
    // Check if the GameStore exists for the given signer's address
    if (!exists<GameStore>(account)) {
        initialize_game(account);
    }

    // Acquire the GameStore for the given signer's address
    let game_store = borrow_global<GameStore>(account);

    // Check if the upgrade_index is within the range of POWERUP_VALUES
    if (upgrade_index >= POWERUP_VALUES.length) {
        // Throw an error - upgrade does not exist
        return abort(ERROR_UPGRADE_DOES_NOT_EXIST);
    }

    // Call the claim function to update the unclaimed diamonds before making the upgrade
    claim(account);

    // Calculate the total cost for the requested upgrade
    let total_upgrade_cost = POWERUP_VALUES[upgrade_index][0] * upgrade_amount;

    // Check if the user has enough diamonds to make the upgrade
    if (game_store.diamonds < total_upgrade_cost) {
        // Throw an error - not enough diamonds to upgrade
        return abort(ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE);
    }

    // Loop through the game_store.upgrades to find the requested upgrade
    let upgrade_existed: bool = false;
    for (let i: u64 = 0; i < game_store.upgrades.length; i++) {
        let powerup = game_store.upgrades[i];
        if (i == upgrade_index) {
            // Increment the amount of the existing upgrade
            powerup.amount += upgrade_amount;
            upgrade_existed = true;
            break;
        }
    }

    // If the upgrade does not exist, create it with the base upgrade_amount
    if (!upgrade_existed) {
        let new_upgrade = Upgrade{name: POWERUP_NAMES[upgrade_index], amount: upgrade_amount};
        game_store.upgrades.push(new_upgrade);
    }

    // Deduct the total_upgrade_cost from the user's diamonds
    game_store.diamonds -= total_upgrade_cost;

    // Move the updated GameStore back to the Global Storage
    move_to(account, game_store);
}


    #[view]
    public fun get_diamonds(account_address: address): u64 acquires GameStore {
    // Check if the GameStore exists for the given account_address
    if (!exists<GameStore>(account_address)) {
        initialize_game(account_address);
    }

    // Acquire the GameStore for the given account_address
    let game_store = borrow_global<GameStore>(account_address);

    // Call the claim function to update the unclaimed diamonds before getting the total diamonds
    claim(account_address);

    // Calculate the total diamonds including unclaimed diamonds
    let total_diamonds = game_store.diamonds + get_unclaimed_diamonds(account_address, timestamp::get_time());

    // Return the total diamonds
    return total_diamonds;
}

    #[view]
   public fun get_diamonds_per_minute(account_address: address): u64 acquires GameStore {
    // Check if the GameStore exists for the given account_address
    if (!exists<GameStore>(account_address)) {
        initialize_game(account_address);
    }

    // Acquire the GameStore for the given account_address
    let game_store = borrow_global<GameStore>(account_address);

    // Call the claim function to update the unclaimed diamonds before calculating DPM
    claim(account_address);

    // Initialize the variable to store the total diamonds per minute (DPM)
    var diamonds_per_minute: u64 = 0;

    // Loop over game_store.upgrades to calculate total DPM
    for (let i: u64 = 0; i < game_store.upgrades.length; i++) {
        let powerup = game_store.upgrades[i];
        let powerup_index = i as usize;

        // Check if the powerup_index is within the range of POWERUP_VALUES vector
        if (powerup_index < POWERUP_VALUES.length) {
            let powerup_dpm = POWERUP_VALUES[powerup_index][1];

            // Add the DPM of this power-up multiplied by its amount to the total DPM
            diamonds_per_minute += powerup.amount * powerup_dpm;
        }
    }

    // Return the total DPM
    return diamonds_per_minute;
}

    #[view]
    public fun get_powerups(account_address: address): vector<Upgrade> acquires GameStore {
    // Check if the GameStore exists for the given account_address
    if (!exists<GameStore>(account_address)) {
        initialize_game(account_address);
    }

    // Acquire the GameStore for the given account_address
    let game_store = borrow_global<GameStore>(account_address);

    // Call the claim function to update the unclaimed diamonds before getting the power-ups
    claim(account_address);

    // Return the list of power-ups from the user's GameStore
    return game_store.upgrades;
}

    /*
    Tests
    DO NOT EDIT
    */
    inline fun test_click_loop(signer: &signer, amount: u64) acquires GameStore {
        let i = 0;
        while (amount > i) {
            click(signer);
            i = i + 1;
        }
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_without_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_with_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 2, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 0, location = diamond_clicker::game)]
    fun test_upgrade_does_not_exist(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 2, location = diamond_clicker::game)]
    fun test_upgrade_does_not_have_enough_diamonds(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_one(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 5);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_two(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 25);

        upgrade(test_one, 1, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_three(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_zhas_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 250);

        upgrade(test_one, 2, 1);
    }
}