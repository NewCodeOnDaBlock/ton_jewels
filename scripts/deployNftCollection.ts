import { Address, Cell, beginCell, toNano } from '@ton/core';
import { NftCollection } from '../wrappers/NftCollection';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const OFFCHAIN_CONTENT_PREFIX = 0x01;
    const metadata_link =
        'https://red-worthy-guppy-897.mypinata.cloud/ipfs/QmVYorCALFHZVLvLpuCKFmEHdZ1ihh74MNbZ6hMrtea2qF/'; // will need to add this IPFS url

    let newContent: Cell = beginCell().storeInt(OFFCHAIN_CONTENT_PREFIX, 8).storeStringRefTail(metadata_link).endCell();
    let owner = Address.parse('0QBF8FbAT-vy21plzrkO9lNpw_XMcUgwojwlPNVE8rVcCsJc');

    let nftCollection = provider.open(
        await NftCollection.fromInit(owner, newContent, {
            $$type: 'RoyaltyParams',
            numerator: 350n, // 350n = 35%
            denominator: 1000n,
            destination: owner,
        }),
    );

    await nftCollection.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        },
    );

    await provider.waitForDeploy(nftCollection.address);
    console.log('Collection smart contract has successfully deployed!');
}
