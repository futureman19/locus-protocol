defmodule Locus.TreasuryTest do
  use ExUnit.Case, async: true

  alias Locus.Treasury
  alias Locus.Schemas.City

  describe "calculate_daily_ubi/2" do
    test "per spec formula: (treasury × 0.001) / citizens" do
      # 100 BSV treasury, 25 citizens
      # Daily pool = 100_000_000_000 × 0.001 = 100_000_000
      # Per citizen = 100_000_000 / 25 = 4_000_000 (0.04 BSV)
      assert Treasury.calculate_daily_ubi(100_000_000_000, 25) == 4_000_000
    end

    test "returns 0 for zero citizens" do
      assert Treasury.calculate_daily_ubi(100_000_000_000, 0) == 0
    end
  end

  describe "calculate_city_ubi/1" do
    test "returns error for non-city phase" do
      city = build_city(:town, 10, 100_000_000_000)
      assert {:error, :ubi_not_active} = Treasury.calculate_city_ubi(city)
    end

    test "returns error for treasury below minimum (100 BSV)" do
      city = build_city(:city, 25, 5_000_000_000)  # 50 BSV < 100 BSV min
      assert {:error, :treasury_below_minimum} = Treasury.calculate_city_ubi(city)
    end

    test "calculates UBI for city phase with sufficient treasury" do
      city = build_city(:city, 25, 100_000_000_000)  # 100 BSV
      {:ok, ubi} = Treasury.calculate_city_ubi(city)
      assert ubi > 0
    end

    test "caps monthly distribution at 1% of treasury" do
      # If UBI formula gives more than 1%/month, it gets capped
      # With 100 BSV and 1 citizen: daily = 0.1 BSV, monthly = 3 BSV = 3%
      # Should cap to 1%/month = 1 BSV, daily = 1/30 = 0.033 BSV
      city = build_city(:city, 1, 100_000_000_000)
      # Add founder to citizens for counting
      city = %{city | citizens: ["founder"], citizen_count: 21}

      {:ok, ubi} = Treasury.calculate_city_ubi(city)

      # Monthly total should not exceed 1% of treasury
      monthly_total = ubi * city.citizen_count * 30
      assert monthly_total <= trunc(city.treasury_bsv * 0.01)
    end
  end

  describe "distribute_ubi/1" do
    test "distributes to all citizens of thriving city" do
      citizens = Enum.map(1..25, fn i -> "citizen_#{i}" end)
      city = %City{
        id: "city1",
        name: "Test",
        territory_id: <<0::256>>,
        founder_pubkey: "founder",
        founded_at: 0,
        phase: :city,
        citizens: citizens,
        citizen_count: 25,
        treasury_bsv: 100_000_000_000,  # 100 BSV
        token_supply: 3_200_000,
        treasury_tokens: 1_600_000,
        founder_tokens_total: 640_000
      }

      {:ok, distributions, updated} = Treasury.distribute_ubi(city)

      assert length(distributions) == 25
      {_pubkey, amount} = hd(distributions)
      assert amount > 0
      assert updated.treasury_bsv < city.treasury_bsv
    end

    test "rejects distribution for non-city phase" do
      city = build_city(:village, 5, 100_000_000_000)
      assert {:error, :ubi_not_active} = Treasury.distribute_ubi(city)
    end
  end

  describe "redemption_rate/2" do
    test "calculates rate as treasury / supply" do
      # 100 BSV treasury / 3.2M tokens = 31,250 sats per token
      assert Treasury.redemption_rate(100_000_000_000, 3_200_000) == 31_250
    end

    test "returns 0 for zero supply" do
      assert Treasury.redemption_rate(100_000_000_000, 0) == 0
    end
  end

  describe "redeem_tokens/3" do
    test "burns tokens and returns BSV at redemption rate" do
      city = build_city(:city, 25, 100_000_000_000)
      city = %{city | token_supply: 3_200_000}

      {:ok, bsv_amount, updated} = Treasury.redeem_tokens(city, 1_000, "redeemer")

      rate = Treasury.redemption_rate(100_000_000_000, 3_200_000)
      assert bsv_amount == rate * 1_000
      assert updated.treasury_bsv == city.treasury_bsv - bsv_amount
      assert updated.token_supply == city.token_supply - 1_000
    end

    test "rejects redemption exceeding treasury" do
      city = build_city(:city, 25, 1_000)  # Tiny treasury
      city = %{city | token_supply: 3_200_000}
      assert {:error, :insufficient_treasury} = Treasury.redeem_tokens(city, 1_000_000, "redeemer")
    end
  end

  describe "vested_founder_tokens/2" do
    test "linear vesting over 12 months" do
      city = build_city(:genesis, 1, 0)
      city = %{city | founded_at: 800_000, founder_tokens_total: 640_000}

      # 0 months
      assert Treasury.vested_founder_tokens(city, 800_000) == 0

      # 6 months (4320 × 6 = 25,920 blocks)
      assert Treasury.vested_founder_tokens(city, 825_920) == 320_000

      # 12 months (fully vested)
      assert Treasury.vested_founder_tokens(city, 851_840) == 640_000

      # Beyond 12 months (capped)
      assert Treasury.vested_founder_tokens(city, 900_000) == 640_000
    end
  end

  # Helpers

  defp build_city(phase, citizen_count, treasury_bsv) do
    citizens = Enum.map(1..citizen_count, fn i -> "citizen_#{i}" end)
    %City{
      id: "city_test",
      name: "Test City",
      territory_id: <<0::256>>,
      founder_pubkey: "founder",
      founded_at: 0,
      phase: phase,
      citizens: citizens,
      citizen_count: citizen_count,
      treasury_bsv: treasury_bsv,
      token_supply: 3_200_000,
      treasury_tokens: 1_600_000,
      founder_tokens_total: 640_000
    }
  end
end
