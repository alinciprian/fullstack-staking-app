"use client";

import LoginPage from "../components/LoginPage";
import Dashboard from "../components/Dashboard";
import { useAccount } from "wagmi";

export default function Home() {
  const { isConnected } = useAccount();
  return (
    <>
      <div>{isConnected ? <Dashboard /> : <LoginPage />}</div>
    </>
  );
}
