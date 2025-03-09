import Balance from "../components/Balance";
import * as React from "react";

import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  CardContent,
} from "@/components/ui/card";
import { usePrivy, useWallets } from "@privy-io/react-auth";
import { useAccount, useDisconnect } from "wagmi";
import {
  getBalance,
  waitForTransactionReceipt,
  readContract,
  writeContract,
} from "@wagmi/core";
import { wagmiConfig } from "../components/providers";
import { useState, useEffect } from "react";
import { devUSDCABI } from "../config/devUSDCABI";
import { SimpleStakingABI } from "../config/SimpleStakingABI";
import { SimpleTokenABI } from "../config/SimpleTokenABI";

export default function Dashboard() {
  const { ready, user, authenticated, connectWallet, logout } = usePrivy();
  const { address, isConnected, isConnecting, isDisconnected } = useAccount();
  const { wallets, ready: walletsReady } = useWallets();
  const { disconnect } = useDisconnect();

  const [balanceSTK, setBalanceSTK] = useState<BalanceType | null>(null);
  const [balancedUSDC, setBalancedUSDC] = useState<BalanceType | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [stakingAmount, setStakingAmount] = useState<number>(0);
  const [withdrawAmount, setWithdrawAmount] = useState<number>(0);
  const [amountstaked, setAmountStaked] = useState<bigint>(0n);
  const [rewardAmount, setRewardAmount] = useState<bigint>(0n);

  const PRECISION = 10 ** 18;

  type BalanceType = {
    formatted: string;
    symbol: string;
  };

  async function fetchSTKBalance() {
    try {
      const balanceSTK = await getBalance(wagmiConfig, {
        address: address!,
        token: "0x170D0227C1db68B6e831C9640C817a23E3AdF6e4",
      });
      setBalanceSTK(balanceSTK);
    } catch (error) {
      console.log("Error fetching STK balance:", error);
    }
  }

  async function fetchdUSDCBalance() {
    try {
      const balanceDUSDC = await getBalance(wagmiConfig, {
        address: address!,
        token: "0x61eC20404dC6CccAA2109F907f8488d0C7929925",
      });
      setBalancedUSDC(balanceDUSDC);
    } catch (error) {
      console.log("Error fetching dUSDC balance:", error);
    }
  }

  const fetchBalances = async () => {
    setIsLoading(true);
    await Promise.all([fetchSTKBalance(), fetchdUSDCBalance()]);
    setIsLoading(false);
  };

  async function handleStaking(_amount: number) {
    setIsLoading(true);
    const txHashApprove = await writeContract(wagmiConfig, {
      abi: SimpleTokenABI,
      address: "0x170D0227C1db68B6e831C9640C817a23E3AdF6e4",
      functionName: "approve",
      args: [
        "0xba0b005b7a83f8f6C2312A15cBb97D980C6E6C0b",
        BigInt(_amount * PRECISION),
      ],
    });
    await waitForTransactionReceipt(wagmiConfig, { hash: txHashApprove });
    const txHash = await writeContract(wagmiConfig, {
      abi: SimpleStakingABI,
      address: "0xba0b005b7a83f8f6C2312A15cBb97D980C6E6C0b",
      functionName: "stake",
      args: [BigInt(_amount * PRECISION)],
    });
    await waitForTransactionReceipt(wagmiConfig, { hash: txHash });
    fetchBalances();
    handleShowBalanceStaked(address!);
    handleShowAvalibleRewards(address!);
    setStakingAmount(0);
    setIsLoading(false);
  }

  async function handleWithdraw(_amount: number) {
    console.log(_amount.toString(), amountstaked.toString());
    const txHash = await writeContract(wagmiConfig, {
      abi: SimpleStakingABI,
      address: "0xba0b005b7a83f8f6C2312A15cBb97D980C6E6C0b",
      functionName: "withdraw",
      args: [BigInt(_amount * PRECISION)],
    });
    await waitForTransactionReceipt(wagmiConfig, { hash: txHash });
    setWithdrawAmount(0);
    fetchBalances();
    handleShowBalanceStaked(address!);
    handleShowAvalibleRewards(address!);
  }

  async function handleShowBalanceStaked(address: `0x${string}`) {
    const result: bigint = (await readContract(wagmiConfig, {
      abi: SimpleStakingABI,
      address: "0xba0b005b7a83f8f6C2312A15cBb97D980C6E6C0b",
      functionName: "getBalanceOfUser",
      args: [address],
    })) as bigint;
    setAmountStaked(result);
  }

  async function handleShowAvalibleRewards(address: `0x${string}`) {
    const result: bigint = (await readContract(wagmiConfig, {
      abi: SimpleStakingABI,
      address: "0xba0b005b7a83f8f6C2312A15cBb97D980C6E6C0b",
      functionName: "getAvalibleReward",
      args: [address],
    })) as bigint;
    setRewardAmount(result);
  }

  async function handleGetReward() {
    const txHash = await writeContract(wagmiConfig, {
      abi: SimpleStakingABI,
      address: "0xba0b005b7a83f8f6C2312A15cBb97D980C6E6C0b",
      functionName: "getReward",
    });
    await waitForTransactionReceipt(wagmiConfig, { hash: txHash });
    handleShowAvalibleRewards(address!);
    fetchdUSDCBalance();
  }

  function handleMax() {
    setWithdrawAmount(Number(amountstaked) / PRECISION);
  }

  useEffect(() => {
    if (isConnected) {
      fetchBalances();
      handleShowBalanceStaked(address!);
      handleShowAvalibleRewards(address!);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isConnected]);

  return (
    <>
      <div className="flex items-center justify-center h-screen gap-8 scale-150">
        <Card className="w-[400px]">
          <CardHeader>
            <CardTitle>Stake your STK</CardTitle>
            <CardDescription>
              {address}
              {isConnected && <span>🟢 connected.</span>}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Balance />
            <p>
              {balanceSTK?.formatted} {balanceSTK?.symbol}{" "}
            </p>
            <p>
              {balancedUSDC?.formatted} {balancedUSDC?.symbol}
            </p>
          </CardContent>
          <CardFooter className="flex justify-between">
            <Button onClick={() => disconnect()}>Disconnect</Button>
          </CardFooter>
        </Card>

        <Card className="w-[350px]">
          <CardHeader>
            <CardDescription>Staking control panel</CardDescription>
          </CardHeader>
          <CardContent>
            {isConnected && address && (
              <>
                <p>
                  {" "}
                  Amount STK already staked:{" "}
                  {(Number(amountstaked) / PRECISION).toFixed(2)}{" "}
                </p>

                <div className="flex w-full max-w-sm items-center space-x-2">
                  <Input
                    type="text"
                    value={stakingAmount}
                    onChange={(e) => setStakingAmount(Number(e.target.value))}
                    disabled={isLoading}
                  />
                  <Button
                    onClick={() => handleStaking(stakingAmount)}
                    disabled={isLoading}
                  >
                    Stake
                  </Button>
                </div>

                <div className="flex w-full max-w-sm items-center space-x-2">
                  <Input
                    type="text"
                    value={withdrawAmount}
                    onChange={(e) => setWithdrawAmount(Number(e.target.value))}
                    disabled={isLoading}
                  />
                  <Button onClick={() => handleWithdraw(withdrawAmount)}>
                    Withdraw
                  </Button>
                  <Button onClick={handleMax}>Max</Button>
                </div>

                <div className="flex justify-between items-center">
                  Your current reward:{" "}
                  {(Number(rewardAmount) / PRECISION).toFixed(2)}{" "}
                  <Button onClick={handleGetReward}>Harvest</Button>
                </div>
              </>
            )}
          </CardContent>
        </Card>
      </div>
      <div>
        <div></div>
      </div>
    </>
  );
}
