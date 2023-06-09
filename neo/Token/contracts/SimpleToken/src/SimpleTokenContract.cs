﻿using System;
using System.ComponentModel;
using System.Numerics;

using Neo;
using Neo.SmartContract.Framework;
using Neo.SmartContract.Framework.Native;
using Neo.SmartContract.Framework.Services;

namespace SimpleToken
{
    [DisplayName("NEO.SimpleTokenContract")]
    [ManifestExtra("Author", "Ammar Voloder")]
    [ManifestExtra("Email", "your@address.invalid")]
    [ManifestExtra("Description", "Controls issuance of the simple token")]
    public class SimpleTokenContract : SmartContract
    {
        const string MAP_NAME = "SimpleTokenContract";
        static readonly ulong InitialSupply = 100; 
        public static BigInteger TotalSupply() => InitialSupply;
        public static string Symbol() => "STK";
        public static ulong Decimals() => 18;

        [DisplayName("Transfer")]
        public static event Action<UInt160, UInt160, BigInteger> OnTransfer;
        private static StorageMap Balances => new StorageMap(Storage.CurrentContext, MAP_NAME);
        private static BigInteger Get(UInt160 key) => (BigInteger) Balances.Get(key);
        private static void Put(UInt160 key, BigInteger value) => Balances.Put(key, value);
        private static void Increase(UInt160 key, BigInteger value)
        {
            Put(key, Get(key) + value);
        }

        private static void Reduce(UInt160 key, BigInteger value)
        {
            var oldValue = Get(key);
            if (oldValue == value)
            {
                Balances.Delete(key);
            }
            else
            {
                Put(key, oldValue - value);
            }
        }

        public static bool Transfer(UInt160 from, UInt160 to, BigInteger amount, object data)
        {
            if (!from.IsValid || !to.IsValid)
            {
                throw new Exception("Parameters from and to should be 20-byte addresses");
            }

            if (amount < 0)
            {
                throw new Exception("The amount must be greater than or equal to zero");
            }

            if (!from.Equals(Runtime.CallingScriptHash) && !Runtime.CheckWitness(from))
            {
                throw new Exception("No authorization");
            }

            if (Get(from) < amount)
            {
                throw new Exception("Insufficient balance");
            }

            Reduce(from, amount);
            Increase(to, amount);
            OnTransfer(from, to, amount);

            if (ContractManagement.GetContract(to) != null)
            {
                Contract.Call(to, "onPayment", CallFlags.None, new object[] { from, amount, data });
            }

            return true;
        }
        public static BigInteger BalanceOf(UInt160 account)
        {
            return Get(account);
        }

        [DisplayName("_deploy")]
        public static void Deploy(object data, bool update)
        {
            if (!update)
            {
                var tx = (Transaction) Runtime.ScriptContainer;
                var owner = (Neo.UInt160) tx.Sender;
                Increase(owner, InitialSupply);
                OnTransfer(null, owner, InitialSupply);
            }
        }
    }
}
