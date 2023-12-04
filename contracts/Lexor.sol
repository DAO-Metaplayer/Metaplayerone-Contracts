// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Burnable, ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/ERC20/IMetaUnit.sol";

contract Lexor is
    ERC20Burnable,
    ReentrancyGuard,
    ERC721Holder
{
    enum VotingType {
        lexorPerMEU,
        percentage,
        addElegibleNFT,
        removeElegibleNFT,
        changeMEUAddress,
        changeMUTDAddress
    }

    struct Staking {
        uint256 uid;
        uint256 metaunit_staking_amount;
        uint256 start_day;
        uint256 end_day;
        uint256 rewardPerDay;
        bool finished;
    }

    struct Activated {
        uint256 uid;
        address owner_of;
        address eligibleNFT;
        uint256 nft_id;
        uint256 crystal_id;
        address meu_address;
        uint256 metaunit_amount;
        uint256 percentage;
        bool activated;
        bool isNFT;
    }
    struct Proposal {
        VotingType voting_type;
        bytes20 value;
        uint256 start_time;
        bool resolved;
    }
    struct Voice {
        address eth_address;
        bool voice;
    }

    uint256 public lexorPerMeu = 3;
    uint256 public startTime;
    uint256 public stakingUid;
    uint256 public activatedCount;
    uint256 private lastActivatedUid;
    uint256 private totalCrystalRewardPercentage;
    Activated[] public _activated;
    Proposal[] public _proposals;
    uint256 public _percentage = 10;
    uint256 private _min_amount = 1000000 ether;
    uint256 private _max_amount = 5000000 ether;

    mapping(address => mapping(uint256 => uint256)) public _activated_addresses;
    mapping(address => uint256) public _activated_addr_bal;
    mapping(address => uint256) public _activated_addr_bal_meu;
    mapping(address => uint256) public _activated_addr_bal_meu_dt;
    mapping(uint256 => mapping(address => bool)) private _is_voted;
    mapping(uint256 => Voice[]) private _voices;
    address public meta_unit_address;
    address public meta_unit_dt_address;
    address public promotion_crystal_address;

    mapping(uint256 => uint256) public globalToLocalStakeUids;
    mapping(address => Staking[]) public stakings;
    mapping(address => mapping(uint => mapping(uint => bool)))
        public hasStakeRewardClaimed;

    address[] private eligibleActivateNFTContracts;

    modifier checkCrystalHolder() {
        require(
            IERC721(promotion_crystal_address).balanceOf(msg.sender) > 0 ||
                _activated_addr_bal[msg.sender] > 0,
            "017"
        );
        _;
    }
    
    modifier isEOA() {
        require(msg.sender == tx.origin, "not Ethereum Outer Address");
        _;
    }

    constructor(
        address _mint_to,
        address _meta_unit_address,
        address _meta_unit_dt_address,
        address _promotion_crystal_address
    ) ERC20("Light Elixir", "LEXOR") {
        _mint(_mint_to, 700000000 * 10 ** 18);
        meta_unit_address = _meta_unit_address;
        meta_unit_dt_address = _meta_unit_dt_address;
        promotion_crystal_address = _promotion_crystal_address;
        startTime = block.timestamp;
    }

    event proposalCreated(
        uint256 uid,
        VotingType voting_type,
        bytes20 value,
        uint256 start_time,
        uint256 end_time
    );
    event voiceSubmited(address eth_address, bool voice);
    event proposalResolved(uint256 uid, bool submited);
    event crystalActivated(
        uint256 uid,
        address owner_of,
        address token_address,
        uint256 token_id,
        uint256 crystal_id,
        address meu_address,
        uint256 amount,
        uint256 percentage,
        bool useNFT
    );
    event crystalDeactivated(uint256 uid, uint256 swapped_uid);
    event stakingCreated(
        uint256 uid,
        uint256 metaunit_staking_amount,
        uint256 start_day,
        uint256 end_day,
        address owner_of,
        bool finished
    );
    event claimed(uint256 uid, uint256 day, uint256 claimed, address owner_of);
    event claimedFromCrystal(uint256 uid, uint256 claimed, address owner_of);

    function viewEligibleNFTs() public view returns (address[] memory) {
        return eligibleActivateNFTContracts;
    }

    function createProposal(
        VotingType voting_type_,
        bytes20 value_
    ) external isEOA checkCrystalHolder {
        if (voting_type_ == VotingType.lexorPerMEU) {
            require(uint160(value_) >= 1 ether, "006");
        } else if (voting_type_ == VotingType.percentage) {
            require(uint160(value_) <= 100, "005");
        } else if (
            voting_type_ == VotingType.changeMEUAddress ||
            voting_type_ == VotingType.changeMUTDAddress
        ) {
            // no checks needed
        } else {
            require(
                IERC721(address(value_)).supportsInterface(0x80ac58cd),
                "016"
            );
        }
        uint256 newProposalUid = _proposals.length;
        _proposals.push(Proposal(voting_type_, value_, block.timestamp, false));
        emit proposalCreated(
            newProposalUid,
            voting_type_,
            value_,
            block.timestamp,
            block.timestamp + 5 days
        );
    }

    function vote(
        uint256 uid_,
        bool voice_
    ) public nonReentrant isEOA checkCrystalHolder {
        require(
            !_is_voted[uid_][msg.sender] &&
                block.timestamp < _proposals[uid_].start_time + 5 days &&
                balanceOf(msg.sender) > 0,
            "011"
        );
        _voices[uid_].push(Voice(msg.sender, voice_));
        emit voiceSubmited(msg.sender, voice_);
        _is_voted[uid_][msg.sender] = true;
    }

    function resolve(
        uint256 uid_
    ) external nonReentrant isEOA checkCrystalHolder {
        Proposal memory proposal = _proposals[uid_];
        require(
            !_proposals[uid_].resolved &&
                block.timestamp > proposal.start_time + 5 days,
            "008"
        );
        uint256 voices_for;
        uint256 voices_against;
        for (uint256 i = 0; i < _voices[uid_].length; i++) {
            Voice memory voice = _voices[uid_][i];
            uint256 balance = balanceOf(voice.eth_address);
            if (voice.voice) voices_for += balance;
            else voices_against += balance;
        }
        bool submited = voices_for > voices_against;
        if (submited) {
            if (proposal.voting_type == VotingType.lexorPerMEU)
                lexorPerMeu = uint256(uint160(proposal.value));
            else if (proposal.voting_type == VotingType.percentage)
                _percentage = uint256(uint160(proposal.value));
            else if (proposal.voting_type == VotingType.addElegibleNFT)
                eligibleActivateNFTContracts.push(address(proposal.value));
            else if (proposal.voting_type == VotingType.removeElegibleNFT) {
                for (uint256 i; i < eligibleActivateNFTContracts.length; i++) {
                    if (
                        eligibleActivateNFTContracts[i] ==
                        address(proposal.value)
                    ) {
                        delete eligibleActivateNFTContracts[i];
                    }
                }
            } else if (proposal.voting_type == VotingType.changeMEUAddress) {
                meta_unit_address = address(proposal.value);
            } else if (proposal.voting_type == VotingType.changeMUTDAddress) {
                meta_unit_dt_address = address(proposal.value);
            }
        }
        emit proposalResolved(uid_, submited);
        _proposals[uid_].resolved = true;
    }

    function hasEligibleNFT(address _contract) public view returns (bool) {
        for (uint i = 0; i < eligibleActivateNFTContracts.length; i++) {
            if (_contract == eligibleActivateNFTContracts[i]) return true;
        }
        return false;
    }

    function activateCrystal(
        address eligible_nft_token_address,
        uint256 eligible_nft_token_id,
        address meu_address,
        uint256 meu_amount,
        uint256 crystal_id,
        uint256 percentage,
        bool useNFT
    ) external nonReentrant isEOA {
        require(percentage <= _percentage, "012");
        require(
            meu_address == meta_unit_address ||
                meu_address == meta_unit_dt_address,
            "015"
        );
        require(
            IERC721(promotion_crystal_address).ownerOf(crystal_id) ==
                msg.sender,
            "013"
        );
        uint256 stake_amount = useNFT ? _max_amount : meu_amount;
        if (useNFT) {
            require(hasEligibleNFT(eligible_nft_token_address), "004");
            IERC721(eligible_nft_token_address).transferFrom(
                msg.sender,
                address(this),
                eligible_nft_token_id
            );
            uint256 refund_amount = _activated_addr_bal_meu[msg.sender];
            if (refund_amount > 0) {
                _activated_addr_bal_meu[msg.sender] = 0;
                IERC20(meta_unit_address).transfer(msg.sender, refund_amount);
            }
            uint256 dt_refund_amount = _activated_addr_bal_meu_dt[msg.sender];
            if (dt_refund_amount > 0) {
                _activated_addr_bal_meu_dt[msg.sender] = 0;
                IERC20(meta_unit_dt_address).transfer(
                    msg.sender,
                    dt_refund_amount
                );
            }
        } else {
            if (meu_amount == 0) {
                // second and following activations can be free
                require(_activated_addr_bal[msg.sender] > 0, "003");
            } else {
                require(
                    meu_amount >= _min_amount && meu_amount <= _max_amount,
                    "014"
                );
                IERC20(meu_address).transferFrom(
                    msg.sender,
                    address(this),
                    meu_amount
                );
                if (meu_address == meta_unit_address) {
                    _activated_addr_bal_meu[msg.sender] += meu_amount;
                } else {
                    _activated_addr_bal_meu_dt[msg.sender] += meu_amount;
                }
            }
        }
        IERC721(promotion_crystal_address).safeTransferFrom(
            msg.sender,
            address(this),
            crystal_id
        );
        _activated_addr_bal[msg.sender] += stake_amount;
        activatedCount++;
        totalCrystalRewardPercentage += percentage;

        _activated.push(
            Activated(
                lastActivatedUid,
                msg.sender,
                eligible_nft_token_address,
                eligible_nft_token_id,
                crystal_id,
                meu_address,
                stake_amount,
                percentage,
                true,
                useNFT
            )
        );

        emit crystalActivated(
            lastActivatedUid,
            msg.sender,
            eligible_nft_token_address,
            eligible_nft_token_id,
            crystal_id,
            meu_address,
            stake_amount,
            percentage,
            useNFT
        );
        lastActivatedUid++;
    }

    function deactivateCrystal(uint256 uid) external nonReentrant isEOA {
        require(uid < _activated.length, "002");
        Activated memory activated = _activated[uid];
        require(activated.activated, "010");
        require(msg.sender == activated.owner_of, "009");
        uint256 stake_amount = activated.isNFT
            ? _max_amount
            : activated.metaunit_amount;
        _activated_addr_bal[msg.sender] -= stake_amount;
        if (activated.isNFT) {
            IERC721(activated.eligibleNFT).transferFrom(
                address(this),
                msg.sender,
                activated.nft_id
            );
        } else {
            if (activated.meu_address == meta_unit_address) {
                if (_activated_addr_bal_meu[msg.sender] > 0) {
                    // only transfer tokens back if not already refunded
                    _activated_addr_bal_meu[msg.sender] -= stake_amount;
                    IERC20(meta_unit_address).transfer(
                        msg.sender,
                        stake_amount
                    );
                }
            } else {
                if (_activated_addr_bal_meu_dt[msg.sender] > 0) {
                    _activated_addr_bal_meu_dt[msg.sender] -= stake_amount;
                    IERC20(meta_unit_dt_address).transfer(
                        msg.sender,
                        stake_amount
                    );
                }
            }
        }
        totalCrystalRewardPercentage -= activated.percentage;
        activatedCount--;        
        uint256 swapped_uid = _activated.length - 1;
        _activated[uid] = _activated[swapped_uid];
        _activated.pop();
        emit crystalDeactivated(uid, swapped_uid);
    }

    function getActivatedList()
        public
        view
        returns (Activated[] memory activated)
    {
        return _activated;
    }

    function getAveragePercent() public view returns (uint256) {
        if (activatedCount == 0) return 0;
        return totalCrystalRewardPercentage / activatedCount;
    }

    function stake(uint256 amount) external nonReentrant isEOA {
        require(_activated.length >= 3, "001");
        require(amount >= 100 ether, "022");
        IMetaUnit(meta_unit_address).burnFrom(msg.sender, amount);
        uint256 averagePercent = getAveragePercent();
        uint256 _amount = (lexorPerMeu *
            ((amount * (100 - averagePercent)) / 100)) / 30;
        uint256 localStakingUid = stakings[msg.sender].length;
        stakings[msg.sender].push(
            Staking(stakingUid, amount, today(), today() + 29, _amount, false)
        );
        globalToLocalStakeUids[stakingUid] = localStakingUid;
        emit stakingCreated(
            stakingUid,
            amount,
            block.timestamp,
            block.timestamp + 29 days,
            msg.sender,
            false
        );
        stakingUid++;
        uint256 nftActiveAmount = (lexorPerMeu * amount * averagePercent) / 100;
        for (uint256 i; i < _activated.length; i++) {
            address crystal_owner = _activated[i].owner_of;
            uint256 activatedBal = _activated_addr_bal[crystal_owner];
            _activated_addresses[crystal_owner][_activated[i].uid] +=
                (nftActiveAmount *
                    (activatedBal > _max_amount ? _max_amount : activatedBal)) /
                (activatedCount * _max_amount);
        }
    }

    function claim(uint uid) public isEOA {
        require(uid <= stakingUid, "007");
        Staking memory staking = stakings[msg.sender][
            globalToLocalStakeUids[uid]
        ];
        uint256 _today = today();
        uint256 total_amount;
        for (uint i = staking.start_day; i <= staking.end_day; i++) {
            if (!hasStakeRewardClaimed[msg.sender][uid][i] && _today >= i) {
                hasStakeRewardClaimed[msg.sender][uid][i] = true;
                total_amount += staking.rewardPerDay;
                emit claimed(uid, i, staking.rewardPerDay, msg.sender);
            }
        }
        if (total_amount > 0) _mint(msg.sender, total_amount);
        if (_today - staking.start_day > 29) {
            stakings[msg.sender][globalToLocalStakeUids[uid]].finished = true;
        }
    }

    function stakerClaimable(uint uid, uint day) public view returns (uint) {
        if (hasStakeRewardClaimed[msg.sender][uid][day]) {
            return 0;
        } else {
            return
                stakings[msg.sender][globalToLocalStakeUids[uid]].rewardPerDay;
        }
    }

    function claimActivatedRewards(uint256 uid) external isEOA nonReentrant {
        require(_activated_addresses[msg.sender][uid] > 0, "028");
        uint256 amount = _activated_addresses[msg.sender][uid];
        _activated_addresses[msg.sender][uid] = 0;
        _mint(msg.sender, amount);
        emit claimedFromCrystal(uid, amount, msg.sender);
    }

    function today() public view returns (uint) {
        uint256 timeStamp = block.timestamp;
        return
            timeStamp < startTime ? 0 : (timeStamp - startTime) / 24 hours + 1;
    }
}
