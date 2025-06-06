"use client";

import { useAccount, useBalance } from "wagmi";

const Balance = () => {
  const { address } = useAccount();
  const { data, isError, isLoading } = useBalance({ address });

  if (isLoading) return <div>Fetching balance…</div>;
  if (isError) return <div>Error fetching balance</div>;
  return (
    <>
      <h2>Your balance</h2>
      {isLoading && <p>fetching balance...</p>}
      {isError && <p>Error fetching balance.</p>}
      {data && (
        <p>
          {data?.formatted} {data?.symbol}
        </p>
      )}
    </>
  );
};

export default Balance;
