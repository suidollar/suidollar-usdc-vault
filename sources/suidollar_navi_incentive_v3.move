module suidollar::suidollar_navi_incentive_v3 {
    use std::ascii::{String};
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use oracle::oracle::{PriceOracle};
    use lending_core::pool::{Pool};
    use lending_core::incentive_v2::{Incentive as IncentiveV2};
    use lending_core::incentive_v3::{Self as incentive_v3, Incentive as IncentiveV3, RewardFund};
    use lending_core::storage::{Storage};
    use lending_core::version;
    use suidollar::suidollar::{Self, MyStruct, Treasury};
    use sui::tx_context::{Self, TxContext};

    const E_INSUFFICIENT_BALANCE: u64 = 3001;
    const E_ZERO_AMOUNT: u64 = 3002;
    const E_INVALID_ASSET: u64 = 3003;

    public fun depositNavi<CoinType>(
        me: &MyStruct,
        _pool: &mut Treasury<CoinType>, 
        clock: &Clock,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        _amount: u64,
        incentive_v2: &mut IncentiveV2, 
        incentive_v3: &mut IncentiveV3, 
        ctx: &mut TxContext 
    ) {
        suidollar::check_allowed(ctx);
        
        assert!(_amount > 0, E_ZERO_AMOUNT);
        
        let treasury_balance = suidollar::get_balance(_pool);
        assert!(balance::value(treasury_balance) >= _amount, E_INSUFFICIENT_BALANCE);
        
        let suiCoin = coin::from_balance(balance::split(treasury_balance, _amount), ctx);
        
        incentive_v3::deposit_with_account_cap(
            clock, storage, pool, asset, suiCoin, incentive_v2, incentive_v3, suidollar::get_account_cap(me)
        )
    }

    public fun withdrawNavi<CoinType>(
        me: &MyStruct,
        _pool: &mut Treasury<CoinType>,
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut IncentiveV3,
        ctx: &TxContext
    ) {
        suidollar::check_allowed(ctx);
        
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let balanceAmount = incentive_v3::withdraw_with_account_cap(
            clock, oracle, storage, pool, asset, amount, incentive_v2, incentive_v3, suidollar::get_account_cap(me)
        );
        
        balance::join(suidollar::get_balance(_pool), balanceAmount);
    }

    public fun borrow<CoinType>(
        me: &MyStruct,
        _pool: &mut Treasury<CoinType>, 
        clock: &Clock,  
        oracle: &PriceOracle, 
        storage: &mut Storage, 
        pool: &mut Pool<CoinType>, 
        asset: u8,    
        amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut IncentiveV3,
        ctx: &TxContext
    ) {
        suidollar::check_allowed(ctx);
        
        assert!(amount > 0, E_ZERO_AMOUNT);
        
        let borrowAmount = incentive_v3::borrow_with_account_cap(
            clock, oracle, storage, pool, asset, amount, incentive_v2, incentive_v3, suidollar::get_account_cap(me)
        );
        
        balance::join(suidollar::get_balance(_pool), borrowAmount);    
    }

    public fun repay<CoinType>(
        me: &MyStruct,
        _pool: &mut Treasury<CoinType>,
        clock: &Clock,
        oracle: &PriceOracle,
        storage: &mut Storage,
        pool: &mut Pool<CoinType>,
        asset: u8,
        _amount: u64,
        incentive_v2: &mut IncentiveV2,
        incentive_v3: &mut IncentiveV3,
        ctx: &mut TxContext 
    ): Balance<CoinType> {

        suidollar::check_allowed(ctx);
        
        assert!(_amount > 0, E_ZERO_AMOUNT);
        
        let treasury_balance = suidollar::get_balance(_pool);
        assert!(balance::value(treasury_balance) >= _amount, E_INSUFFICIENT_BALANCE);
        
        let wethCoin = coin::from_balance(balance::split(treasury_balance, _amount), ctx);
        
        incentive_v3::repay_with_account_cap(
            clock, oracle, storage, pool, asset, wethCoin, incentive_v2, incentive_v3, suidollar::get_account_cap(me)
        )
    }

    public fun claimRewards<RewardCoinType>(
        me: &MyStruct,
        clock: &Clock,
        incentive_v3: &mut IncentiveV3,
        storage: &mut Storage,
        reward_fund: &mut RewardFund<RewardCoinType>,
        coin_types: vector<String>,
        rule_ids: vector<address>,
        ctx: &TxContext
    ): Balance<RewardCoinType> {

        suidollar::check_allowed(ctx);
        
        assert!(std::vector::length(&coin_types) > 0, E_INVALID_ASSET);
        assert!(std::vector::length(&rule_ids) > 0, E_INVALID_ASSET);
        
        incentive_v3::claim_reward_with_account_cap(
            clock, incentive_v3, storage, reward_fund, coin_types, rule_ids, suidollar::get_account_cap(me)
        )
    }
} 
