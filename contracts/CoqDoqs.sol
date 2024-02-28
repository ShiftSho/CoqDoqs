import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./IJoeRouter01.sol";
import "./IViagraStaking.sol";

pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

contract CoqDoqs is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable {
  using Strings for uint256;
  using SafeERC20 for IERC20;

  IJoeRouter01 public joeRouter;
  IViagraStaking public stakingContract;

  uint256 private _tokenIds;
  string private baseURI = "";
  uint256 private constant limit = 6900;
  uint256 public currentEpoch;
  uint256 public totalAvailableRewards;
  address private coqERC20Contract = 0x938B097cCC8D35d0D39F9BbbAE0914C7d59F0Fca;  // Testnet address - MUST CHANGE
  address private viagraERC20Contract = 0xCe1aD50F74Abe70eB53b4EaC864E36Fb00EDB36E; // Testnet address - MUST CHANGE
  address private devWallet = 0x938956A82cFf874deb8c56e1d97CDb45eCD2dB8F;
  bool private publicCanMintNFT = false;

  mapping(uint256 => uint256) public tokenEpoch;

  event Mint(address indexed to, uint256 indexed tokenId);
  event DepositedToStaking(uint256 amount);
  event RewardsHarvested(address indexed user, uint256 amount);

  constructor(address _routerAddress, address _stakingContractAddress) ERC721("CoqDoqs", "COQ") {
    require(_routerAddress != address(0) && _stakingContractAddress != address(0), "Zero address is not allowed");
    joeRouter = IJoeRouter01(_routerAddress);
    stakingContract = IViagraStaking(_stakingContractAddress);
    currentEpoch = 1;
  }

  /// @notice Internal Mint an item for a given address
  /// @param to recipient address
  function _mintItem(address to) private returns (uint256) {
    require(to != address(0), "Zero address is not allowed");
    _tokenIds += 1;
    uint256 newTokenId = _tokenIds;
    _mint(to, newTokenId);
    _setTokenURI(newTokenId, string(abi.encodePacked(newTokenId.toString(), ".json")));
    tokenEpoch[newTokenId] = currentEpoch;
    emit Mint(to, newTokenId);
    return newTokenId;
  }

  modifier zeroAddressGuard(address addy) {
    /// @dev guard against zero address
    require(addy != address(0), "Address cannot be the zero address");
    _;
  }

  modifier allAdressesGuard() {
    /// @dev guard against coqcontract, price contract, and devwallet not being set.
    require(coqERC20Contract != address(0), "coqERC20Contract is still zero address");
    require(devWallet != address(0), "DEV Wallet is still zero address");
    require(keccak256(abi.encodePacked(baseURI)) != keccak256(abi.encodePacked("")), "Base URI is not set");
    _;
  }

  /// @notice Check if this contract has been approved by the buyer to spend the required amount of COQ
  /// @param buyer address
  function approvedForCoq(address buyer, uint256 amount)
  public
  view
  zeroAddressGuard(buyer)
  returns (bool) {
      IERC20 token = IERC20(coqERC20Contract);
      uint256 allowance = token.allowance(buyer, address(this));
      return allowance >= amount;
  }

  /// @notice The total number of NFTs the address has
  function totalNumberOfTokens(address tokenOwner)
  public
  view
  zeroAddressGuard(tokenOwner)
  returns (uint256) {
      return this.balanceOf(tokenOwner);
  }

  /// @notice The price for an NFT
  /// @param id The ID of the NFT
  function getNFTPrice(uint256 id) public view returns (uint256) {
      // Prices set for different epochs with $COQ's 18 decimal places
      uint256 firstEpochPrice = 42_000_000 * 1e18; // 42,000,000 $COQ
      uint256 secondEpochPrice = 69_000_000 * 1e18; // 69,000,000 $COQ
      uint256 thirdEpochPrice = 100_000_000 * 1e18; // 100,000,000 $COQ

      uint256 epochLength = limit / 3; // Divide the total limit into three equal parts for epochs

      if (id >= 1 && id <= epochLength) {
          return firstEpochPrice;
      } else if (id > epochLength && id <= epochLength * 2) {
          currentEpoch++;
          return secondEpochPrice;
      } else if (id > epochLength * 2 && id <= limit) {
          currentEpoch++;
          return thirdEpochPrice;
      } else {
          // This case should ideally never be hit since ID should always be within the limit
          revert("Invalid NFT ID");
      }
  }

  /// @notice Mint an item for a given address  
  /// @param to recipient address
  function requestMint(address to) external zeroAddressGuard(to) allAdressesGuard() returns (uint256) {
    // make sure coqdoqs are available to public for minting
    require(publicCanMintNFT, "CoqDoqs are unable to see patients at this time.");

    // make sure we have more left to mint
    require(_tokenIds < limit , "Coq Doqs are all with their patients!");

    // increment the token - need to do this to get the price for the token they will get
    // the actual increment will happen in the _mint function
    uint256 tokenId = _tokenIds + 1;

    // get the nft price in COQ
    uint256 epochNFTPrice = getNFTPrice(tokenId);

    // make sure this contract is approved for transfer Coq
    require(approvedForCoq(to, epochNFTPrice), "COQ hasn't been approved for transfer");

    // transfer the COQ tokens
    _transferCoqTokens(to, epochNFTPrice, coqERC20Contract);

    // swap COQ tokens for Viagra
    swapCOQforVIAGRA(epochNFTPrice);

    // do the mint
    return _mintItem(to);
  }

  /**
  * @dev Given an amount and a currency, transfer the currency to this contract.
  */
  function _transferCoqTokens(address from, uint256 amount, address currency) internal {
    uint256 devAmount = amount * 58 / 100;
    IERC20 token = IERC20(currency);
    token.safeTransferFrom(from, devWallet, devAmount);
  }

  function swapCOQforVIAGRA(uint256 coqAmount) internal {
    require(IERC20(coqERC20Contract).balanceOf(address(this)) >= coqAmount, "Insufficient COQ balance");

    uint256 coqAmountTransferred = coqAmount * 42 / 100;

    IERC20(coqERC20Contract).approve(address(joeRouter), coqAmountTransferred);

    address[] memory path = new address[](2);
    path[0] = coqERC20Contract; // Replace with COQ token address
    path[1] = viagraERC20Contract; // Replace with VIAGRA token address

    // Fetch current amount out min based on pool reserves
    uint256[] memory amounts = joeRouter.getAmountsOut(coqAmount, path);
    uint256 amountOutMin = amounts[amounts.length - 1];  // Last element is the amount of tokens out

    // Apply slippage tolerance
    uint256 minimumAmountOut = (amountOutMin * (10000 - 1500)) / 10000;

    uint [] memory amount = joeRouter.swapExactTokensForTokens(
        coqAmountTransferred,
        minimumAmountOut, // Set minimum amount of VIAGRA tokens willing to accept
        path,
        address(this), // Where to send the VIAGRA tokens
        block.timestamp + 600 // Deadline (e.g., 10 minutes from now)
    );
    require(amounts[amounts.length - 1] >= minViagraAmount, "Swap did not meet minimum VIAGRA amount");
  }

  function depositViagraToStaking() public onlyOwner {
    uint256 viagraAmount = IERC20(viagraTokenAddress).balanceOf(address(this));
    require(viagraAmount > 0, "No Viagra to stake");

    IERC20(viagraTokenAddress).approve(viagraStakingContractAddress, viagraAmount);
    IViagraStaking(viagraStakingContractAddress).deposit(viagraAmount);

    emit DepositedToStaking(viagraAmount);
  }

  function harvestCoqRewards() public {
    IViagraStaking(viagraStakingContractAddress).harvestRewards();
    totalAvailableRewards = IViagraStaking(viagraStakingContractAddress).pendingRewards(address(this));
  }

  function claimCoqRewards() public {
    require(balanceOf(msg.sender) > 0, "You must be a patient of at least one Coq Doq to claim");

    // Total rewards available for the sender
    uint256 totalRewards = 0;

    // Number of tokens owned by the sender
    uint256 numOwned = balanceOf(msg.sender);

    // Iterate over all tokens owned by the sender
    for (uint256 index = 0; index < numOwned; index++) {
        // Get token ID for the owned token
        uint256 tokenId = tokenOfOwnerByIndex(msg.sender, index);

        // Determine the epoch for the token
        uint256 mintPrice = getNFTPrice(tokenID);

        // Calculate the amount of $VIAGRA staked (42% of mint price)
        uint256 viagraStaked = (mintPrice * 42) / 100;

        // Calculate rewards for this token (this might involve a more complex formula based on your staking logic)
        // For example, this could involve checking the total amount staked, the rewards pool, and so forth.
        // Here we use a placeholder function `calculateRewardsForViagraStaked` which you would need to define
        // based on your specific rewards distribution logic.
        uint256 rewardsForToken = calculateRewardsForViagraStaked(viagraStaked);

        // Accumulate the rewards for this token into the total rewards
        totalRewards += rewardsForToken;
    }

    // Send the calculated COQ rewards to the NFT holder
    IERC20(coqTokenAddress).transfer(msg.sender, totalRewards);

    // Emit an event for the harvested rewards
    emit RewardsHarvested(msg.sender, totalRewards);
  }


  function calculateRewardsForViagraStaked(uint256 viagraStaked) internal view returns (uint256) {
      // Rewards calculation based on the amount of $VIAGRA staked
      uint TotalRewards = IViagraStaking(viagraStakingContractAddress).pendingRewards(this.address);
      uint TotalStaked = IViagraStaking(viagraStakingContractAddress).totalStaked(this.address);
      uint shareOfStake = viagraStaked / TotalStaked;
      return TotalRewards * shareOfStake;

  }



  /// @notice Change the BaseURI 
  /// @param newBaseURI string of the new base URI
  function setBaseURI(string memory newBaseURI)
      public
      onlyOwner
  {
    baseURI = newBaseURI;
  }

  /// @notice Set if the public can mint an NFT or not
  /// @param canMintNFT can the public mint an NFT
  function setPublicCanMintNFT(bool canMintNFT)
      onlyOwner
      public
  {
    publicCanMintNFT = canMintNFT;
  }

  /// @notice Set the COQ ERC20 contract address
  /// @param coqContract the COQ erc20 contract
  function setCoqContract(address coqContract)
      onlyOwner
      public
  {
    coqERC20Contract = coqContract;
  }


  /// @notice Set the Dev Wallet Address
  /// @param devWalletAddress the Dev Wallet Address
  function setDevWallet(address devWalletAddress)
      onlyOwner
      public
  {
    devWallet = devWalletAddress;
  }

  /// @notice Override of the burn function
  /// @param tokenId value of the token id to be burned
  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  /// @notice Get the token URI for a given token Id
  /// @param tokenId value of the token id
  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  /// @notice Get the current base URI
  function _baseURI() internal override view virtual returns (string memory) {
    return baseURI;
  }

  
  /// @notice Override of the beforeTokenTransfer function
  /// @param from the from address
  /// @param to the to address
  /// @param tokenId value of the token id to be burned
  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  /// @notice Override of the supportsInterface function
  /// @param interfaceId the id of the interface
  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
