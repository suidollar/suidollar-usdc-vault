module suidollar::suidollar {
    use sui::event;
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use oracle::oracle::{PriceOracle};
    use lending_core::account::{AccountCap};
    use lending_core::pool::{Pool}; 
    use lending_core::lending::{Self};
    use lending_core::incentive::{Incentive as IncentiveV1};
    use lending_core::incentive_v2::{Incentive};
    use lending_core::incentive_v2::{Self as incentive_v2, Incentive as IncentiveV2 , IncentiveFundsPool}; 
    use lending_core::storage::{Storage};

    const BLUEFIN_ADDRESS: address = @0xa5241d2ebbc9e93d5a9041dde288a6bfc46fccaf1c15ad0b85fd80806010e4c6;

    public struct MyStruct has key, store {
        id: UID, 
        navi_account: AccountCap
    }

    public struct Treasury<phantom CoinType> has key, store {
        id: UID,
        balance: Balance<CoinType>,
        fee_balance: Balance<CoinType>,
    }
 
    public struct Deposit has copy, drop {
        user_address: address,
        deposit_amount: u64
    }

    public struct Withdraw has copy, drop {
        user_address: address,
        amount: u64
    }

    // Struct to hold the dynamic fee percentage
    public struct FeeConfig has key, store {
        id: UID,
        fee_percentage: u64, // Fee percentage as a dynamic value
    }

    fun init(ctx: &mut TxContext) {
        let cap = lending::create_account(ctx);
        transfer::share_object(MyStruct{id: object::new(ctx), navi_account: cap});
        let fee_config = FeeConfig {
            id: object::new(ctx),
            fee_percentage: 25, // Set default fee percentage
        };
        transfer::share_object(fee_config);
    }

    public fun check_allowed(ctx: &TxContext) {
        let caller = tx_context::sender(ctx);
        assert!(caller == BLUEFIN_ADDRESS, 100); // Error code 100 for unauthorized access
    }

    public fun set_fee_percentage(fee_config: &mut FeeConfig, new_fee: u64, ctx: &TxContext) {
        check_allowed(ctx);
        assert!(new_fee <= 10000, 10000);
        fee_config.fee_percentage = new_fee;
    }

    public fun create_treasury<CoinType>(ctx: &mut TxContext){
        check_allowed(ctx);
       let pool = Treasury {
            id: object::new(ctx),
            balance: balance::zero<CoinType>(),
            fee_balance: balance::zero<CoinType>(),
        };
        transfer::share_object(pool);
    }

    public fun deposit<CoinType>( pool: &mut Treasury<CoinType>,  deposit: Coin<CoinType>,   ctx: &mut TxContext  ) {
        check_allowed(ctx);
        let deposit_balance = coin::into_balance(deposit);
        balance::join(&mut pool.balance, deposit_balance);
    }

    public fun userDeposit<CoinType>( pool: &mut Treasury<CoinType>,  mut deposit: Coin<CoinType>, fee_config: &FeeConfig, ctx: &mut TxContext ) {
    let total_amount = coin::value(&deposit);
    let min_amount = 10000 /  fee_config.fee_percentage;
    assert!(total_amount >= min_amount, 000);
    let fee_amount = total_amount *  fee_config.fee_percentage / 10000;
    let remaining_amount = total_amount - fee_amount;
    let fee_coin = coin::split(&mut deposit, fee_amount, ctx);
    event::emit(Deposit { user_address: ctx.sender(), deposit_amount: remaining_amount  });
    balance::join(&mut pool.fee_balance, coin::into_balance(fee_coin));
    balance::join(&mut pool.balance,coin::into_balance(deposit) );
}


    public fun withdraw<CoinType>(_pool: &mut Treasury<CoinType>, _amount: u64, ctx: &mut TxContext) {
         check_allowed(ctx); // Only the owner can call this function
        let _coin = coin::from_balance(balance::split(&mut _pool.balance, _amount), ctx);
        sui::transfer::public_transfer(_coin, BLUEFIN_ADDRESS);
    }


    public fun userWithdraw<CoinType>(_pool: &mut Treasury<CoinType>,userAddress: address , _amount: u64, ctx: &mut TxContext) {
        check_allowed(ctx); // Only the owner can call this function
        let _coin = coin::from_balance(balance::split(&mut _pool.balance, _amount), ctx);
        sui::transfer::public_transfer(_coin, userAddress);
        event::emit(Withdraw { user_address: ctx.sender(), amount: _amount  });
    }


    public fun withdrawFees<CoinType>(_pool: &mut Treasury<CoinType>, _amount: u64, ctx: &mut TxContext) {
         check_allowed(ctx); // Only the owner can call this function
        let _coin = coin::from_balance(balance::split(&mut _pool.fee_balance, _amount), ctx);
        sui::transfer::public_transfer(_coin, BLUEFIN_ADDRESS);
    }


    public fun depositNavi<CoinType>(
        _pool: &mut Treasury<CoinType>,
        me: &MyStruct, 
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        _amount:u64,
        incentive_v1: &mut IncentiveV1, 
        incentive_v2: &mut IncentiveV2,
        ctx: &mut TxContext 
    ) {
        check_allowed(ctx);
        let suiCoin = coin::from_balance(balance::split(&mut _pool.balance, _amount), ctx);
        incentive_v2::deposit_with_account_cap(clock, storage, pool, asset, suiCoin , incentive_v1, incentive_v2, &me.navi_account)
    }

        public fun withdrawNavi<CoinType>(
        _pool: &mut Treasury<CoinType>,
        me: &MyStruct,
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v1: &mut IncentiveV1,
        incentive_v2: &mut Incentive,
        ctx: &TxContext // Added to get the context
    ){
        check_allowed(ctx);
        let balanceAmount =  incentive_v2::withdraw_with_account_cap(clock, oracle, storage, pool, asset, amount, incentive_v1, incentive_v2, &me.navi_account);
        balance::join(&mut _pool.balance, balanceAmount);
}

    public fun borrow<CoinType>(
        _pool: &mut Treasury<CoinType>,
        me: &MyStruct, 
        clock: &Clock,  
        oracle: &PriceOracle, 
        storage: &mut Storage, 
        pool: &mut Pool<CoinType>, 
        asset: u8,    
        amount: u64, 
        incentive: &mut Incentive,
        ctx: &TxContext // Added to get the context
    )
    {
        check_allowed(ctx);
        let borrowAmount =  incentive_v2::borrow_with_account_cap(clock, oracle, storage, pool, asset, amount, incentive, &me.navi_account);
        balance::join(&mut _pool.balance, borrowAmount);    
    }

        public fun repay<CoinType>(
         _pool: &mut Treasury<CoinType>,
        me: &MyStruct,
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        _amount: u64,
        incentive: &mut Incentive,
        ctx: &mut TxContext 
    ): Balance<CoinType> 
    {
        check_allowed(ctx);
        let wethCoin = coin::from_balance(balance::split(&mut _pool.balance, _amount), ctx);
        incentive_v2::repay_with_account_cap(clock, oracle, storage, pool, asset, wethCoin, incentive, &me.navi_account)
    }

        public fun claimRewards<CoinType>(
        me: &MyStruct,
        clock: &Clock,
        incentive: &mut Incentive,
        funds_pool: &mut IncentiveFundsPool<CoinType>,
        storage: &mut Storage,
        asset: u8,
        option: u8,
        ctx: &TxContext // Added to get the context
    ): Balance<CoinType>
    {
        check_allowed(ctx);
        incentive_v2::claim_reward_with_account_cap(clock, incentive, funds_pool, storage, asset, option, &me.navi_account)
    }

}
