const { utils } = require("ethers");

export const n18 = (amount: string) => {
  return utils.parseUnits(amount, "ether");
};
