// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.24;

interface IContracts {
    function SLIS_BNB_PROVIDER() external view returns (address);
    function YIELDNEST_MPC_WALLET() external view returns (address);
    function SLIS_BNB() external view returns (address);
    function WBNB() external view returns (address);
    function SLIS_BNB_STAKE_MANAGER() external view returns (address);
    function INTERACTION() external view returns (address);
    function YNBNBX() external view returns (address);
    function AS_BNB_MINTER() external view returns (address);
    function ASBNB() external view returns (address);
    function YNBNBX_PROVIDER() external view returns (address);
    function YNWBNBK() external view returns (address);
    function YNBNBK() external view returns (address);
    function YNCLISBNBK() external view returns (address);
    function BNBX() external view returns (address);
    function BNBX_STAKE_MANAGER() external view returns (address);
}

library MainnetContracts {
    // YieldNest
    address public constant YNCLISBNB = 0x1cBfbC3CB909Fb0BF0E511AFAe6cDBa6ba5e2252;
    // YieldNest BNBx
    address public constant YNBNBX = 0x32C830f5c34122C6afB8aE87ABA541B7900a2C5F;

    address public constant SLIS_BNB_PROVIDER = 0xfD31e1C5e5571f8E7FE318f80888C1e6da97819b;
    address public constant YIELDNEST_MPC_WALLET = 0x24bcA21172B564474734Ae25900663BCC964d92b;
    address public constant SLIS_BNB = 0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant SLIS_BNB_STAKE_MANAGER = 0x1adB950d8bB3dA4bE104211D5AB038628e477fE6;
    address public constant INTERACTION = 0xB68443Ee3e828baD1526b3e0Bdf2Dfc6b1975ec4;
    address public constant YNASBNBK = 0x504A89a3Ed6A51D17D4f936E58476c779EE7315b;
    address public constant AS_BNB_MINTER = 0x2F31ab8950c50080E77999fa456372f276952fD8;
    address public constant ASBNB = 0x77734e70b6E88b4d82fE632a168EDf6e700912b6;
    address public constant YNBNBX_PROVIDER = 0xcff9D39E1C8e675868A3105b619a987cAA147d59;
    address public constant CLIS_BNB = 0x4b30fcAA7945fE9fDEFD2895aae539ba102Ed6F6;
    address public constant YNWBNBK = 0x6EC6b7F106674d6D82b7b24446C7ebaf349d59A1;
    address public constant YNBNBK = 0x304B5845b9114182ECb4495Be4C91a273b74B509;
    address public constant YNCLISBNBK = 0x03276919F8b6eE37BA8EE4ee68a1c5f48b667834;
    address public constant BNBX = 0x1bdd3Cf7F79cfB8EdbB955f20ad99211551BA275;
    address public constant BNBX_STAKE_MANAGER = 0x3b961e83400D51e6E1AF5c450d3C7d7b80588d28;
}

library TestnetContracts {
    address public constant SLIS_BNB = 0xCc752dC4ae72386986d011c2B485be0DAd98C744;
    address public constant CLIS_BNB = 0x3dC5a40119B85d5f2b06eEC86a6d36852bd9aB52;
    address public constant SLIS_BNB_PROVIDER = 0x11f6aDcb73473FD7bdd15f32df65Fa3ECdD0Bc20;
    address public constant INTERACTION = 0x70C4880A3f022b32810a4E9B9F26218Ec026f279;
    address public constant WBNB = 0x2F472b32b8041E51e53EeC52e87c7060EA9C7eE8;
    address public constant YIELDNEST_MPC_WALLET = 0x24bcA21172B564474734Ae25900663BCC964d92b;
    address public constant SLIS_BNB_STAKE_MANAGER = 0xc695F964011a5a1024931E2AF0116afBaC41B31B;
    address public constant YNBNBX = 0x0000000000000000000000000000000000000000;
    address public constant AS_BNB_MINTER = 0x0000000000000000000000000000000000000000;
    address public constant ASBNB = 0x0000000000000000000000000000000000000000;
    address public constant YNBNBX_PROVIDER = 0x0000000000000000000000000000000000000000;
    address public constant YNWBNBK = 0x0000000000000000000000000000000000000000;
    address public constant YNBNBK = 0x0000000000000000000000000000000000000000;
    address public constant YNCLISBNBK = 0x0000000000000000000000000000000000000000;
    address public constant BNBX = 0x0000000000000000000000000000000000000000;
    address public constant BNBX_STAKE_MANAGER = 0x0000000000000000000000000000000000000000;
}

contract BscContracts is IContracts {
    function SLIS_BNB_PROVIDER() external pure returns (address) {
        return MainnetContracts.SLIS_BNB_PROVIDER;
    }

    function YIELDNEST_MPC_WALLET() external pure returns (address) {
        return MainnetContracts.YIELDNEST_MPC_WALLET;
    }

    function SLIS_BNB() external pure returns (address) {
        return MainnetContracts.SLIS_BNB;
    }

    function WBNB() external pure returns (address) {
        return MainnetContracts.WBNB;
    }

    function SLIS_BNB_STAKE_MANAGER() external pure returns (address) {
        return MainnetContracts.SLIS_BNB_STAKE_MANAGER;
    }

    function INTERACTION() external pure returns (address) {
        return MainnetContracts.INTERACTION;
    }

    function YNBNBX() external pure returns (address) {
        return MainnetContracts.YNBNBX;
    }

    function AS_BNB_MINTER() external pure returns (address) {
        return MainnetContracts.AS_BNB_MINTER;
    }

    function ASBNB() external pure returns (address) {
        return MainnetContracts.ASBNB;
    }

    function YNBNBX_PROVIDER() external pure returns (address) {
        return MainnetContracts.YNBNBX_PROVIDER;
    }

    function YNWBNBK() external pure returns (address) {
        return MainnetContracts.YNWBNBK;
    }

    function YNBNBK() external pure returns (address) {
        return MainnetContracts.YNBNBK;
    }

    function YNCLISBNBK() external pure returns (address) {
        return MainnetContracts.YNCLISBNBK;
    }

    function BNBX() external pure returns (address) {
        return MainnetContracts.BNBX;
    }

    function BNBX_STAKE_MANAGER() external pure returns (address) {
        return MainnetContracts.BNBX_STAKE_MANAGER;
    }
}

contract ChapelContracts is IContracts {
    function SLIS_BNB_PROVIDER() external pure returns (address) {
        return TestnetContracts.SLIS_BNB_PROVIDER;
    }

    function YIELDNEST_MPC_WALLET() external pure returns (address) {
        return TestnetContracts.YIELDNEST_MPC_WALLET;
    }

    function SLIS_BNB() external pure returns (address) {
        return TestnetContracts.SLIS_BNB;
    }

    function WBNB() external pure returns (address) {
        return TestnetContracts.WBNB;
    }

    function SLIS_BNB_STAKE_MANAGER() external pure returns (address) {
        return TestnetContracts.SLIS_BNB_STAKE_MANAGER;
    }

    function INTERACTION() external pure returns (address) {
        return TestnetContracts.INTERACTION;
    }

    function YNBNBX() external pure returns (address) {
        return TestnetContracts.YNBNBX;
    }

    function AS_BNB_MINTER() external pure returns (address) {
        return TestnetContracts.AS_BNB_MINTER;
    }

    function ASBNB() external pure returns (address) {
        return TestnetContracts.ASBNB;
    }

    function YNBNBX_PROVIDER() external pure returns (address) {
        return TestnetContracts.YNBNBX_PROVIDER;
    }

    function YNWBNBK() external pure returns (address) {
        return TestnetContracts.YNWBNBK;
    }

    function YNBNBK() external pure returns (address) {
        return TestnetContracts.YNBNBK;
    }

    function BNBX() external pure returns (address) {
        return TestnetContracts.BNBX;
    }

    function BNBX_STAKE_MANAGER() external pure returns (address) {
        return TestnetContracts.BNBX_STAKE_MANAGER;
    }

    function YNCLISBNBK() external pure returns (address) {
        return TestnetContracts.YNCLISBNBK;
    }
}
