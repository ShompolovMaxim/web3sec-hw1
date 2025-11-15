package main

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"log"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	ethcrypto "github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/joho/godotenv"
)

func main() {
	data, err := os.ReadFile("out/Bridge.sol/Bridge.json")
	if err != nil {
		log.Fatal(err)
	}

	var obj map[string]json.RawMessage
	if err := json.Unmarshal(data, &obj); err != nil {
		log.Fatal(err)
	}

	bridgeABI := string(obj["abi"])

	_ = godotenv.Load()

	aRPC := getEnv("CHAIN_A_RPC", "ws://localhost:8545")
	bRPC := getEnv("CHAIN_B_RPC", "ws://localhost:8546")
	aBridge := common.HexToAddress(getEnv("BRIDGE_A_ADDRESS", ""))
	bBridge := common.HexToAddress(getEnv("BRIDGE_B_ADDRESS", ""))
	privKeyHex := getEnv("PRIVATE_KEY", "")

	if aBridge == (common.Address{}) || bBridge == (common.Address{}) || privKeyHex == "" {
		log.Fatal("Set BRIDGE_A_ADDRESS, BRIDGE_B_ADDRESS, PRIVATE_KEY")
	}

	clientA, err := ethclient.Dial(aRPC)
	if err != nil {
		log.Fatal("Chain A:", err)
	}
	defer clientA.Close()

	clientB, err := ethclient.Dial(bRPC)
	if err != nil {
		log.Fatal("Chain B:", err)
	}
	defer clientB.Close()

	abiParsed, err := abi.JSON(strings.NewReader(bridgeABI))
	if err != nil {
		log.Fatal("ABI:", err)
	}

	privKey, err := ethcrypto.HexToECDSA(strings.TrimPrefix(privKeyHex, "0x"))
	if err != nil {
		log.Fatal("Private key:", err)
	}
	fromAddr := ethcrypto.PubkeyToAddress(privKey.PublicKey)

	ctx := context.Background()

	log.Println("Relay started, running symmetric handlers for both chains...")

	go runDirection(ctx, clientA, clientB, aBridge, bBridge, abiParsed, privKey, fromAddr)
	go runDirection(ctx, clientB, clientA, bBridge, aBridge, abiParsed, privKey, fromAddr)

	select {}
}

func runDirection(ctx context.Context, srcClient, dstClient *ethclient.Client, srcBridge, dstBridge common.Address, abiParsed abi.ABI, privKey *ecdsa.PrivateKey, fromAddr common.Address) {
	depositSig := ethcrypto.Keccak256Hash([]byte("Deposit(address,uint256,address,uint256,uint256)"))

	processedNonces := make(map[uint64]bool)

	chainID, err := dstClient.NetworkID(ctx)
	if err != nil {
		log.Println("Failed to get destination chain ID:", err)
		return
	}

	for {
		query := ethereum.FilterQuery{
			Addresses: []common.Address{srcBridge},
			Topics:    [][]common.Hash{{depositSig}},
		}

		logsChan := make(chan types.Log)
		sub, err := srcClient.SubscribeFilterLogs(ctx, query, logsChan)
		if err != nil {
			log.Println("Subscribe error:", err)
			continue
		}

		for {
			select {
			case err := <-sub.Err():
				log.Println("Subscription error:", err)
				sub.Unsubscribe()
				return
			case vLog := <-logsChan:
				if len(vLog.Topics) < 4 {
					continue
				}

				from := common.BytesToAddress(vLog.Topics[1].Bytes())
				toChainId := new(big.Int).SetBytes(vLog.Topics[2].Bytes())
				to := common.BytesToAddress(vLog.Topics[3].Bytes())

				var event struct {
					Amount *big.Int
					Nonce  *big.Int
				}
				if err := abiParsed.UnpackIntoInterface(&event, "Deposit", vLog.Data); err != nil {
					log.Println("Parse event:", err)
					continue
				}

				nonce := event.Nonce.Uint64()
				if processedNonces[nonce] {
					log.Printf("Nonce %d already processed", nonce)
					continue
				}

				if toChainId.Cmp(chainID) != 0 {
					log.Printf("Skipping deposit nonce=%d intended for chain %s", nonce, toChainId.String())
					continue
				}

				log.Printf("Deposit: from=%s to=%s amount=%s nonce=%d", from.Hex(), to.Hex(), event.Amount, nonce)

				input, err := abiParsed.Pack("receiveFromOtherChain", to, event.Amount, event.Nonce)
				if err != nil {
					log.Println("Pack:", err)
					continue
				}

				nonceVal, err := dstClient.PendingNonceAt(ctx, fromAddr)
				if err != nil {
					log.Println("Nonce:", err)
					continue
				}

				gasPrice, err := dstClient.SuggestGasPrice(ctx)
				if err != nil {
					log.Println("Gas price:", err)
					continue
				}

				tx := types.NewTransaction(nonceVal, dstBridge, big.NewInt(0), 300000, gasPrice, input)
				signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), privKey)
				if err != nil {
					log.Println("Sign:", err)
					continue
				}

				if err := dstClient.SendTransaction(ctx, signedTx); err != nil {
					log.Println("Send:", err)
					continue
				}

				log.Printf("Transaction sent: %s", signedTx.Hash().Hex())

				receipt, err := bind.WaitMined(ctx, dstClient, signedTx)
				if err != nil {
					log.Println("Wait mined:", err)
					continue
				}

				if receipt.Status == 0 {
					log.Println("Transaction failed")
					continue
				}

				processedNonces[nonce] = true

				log.Printf("Transaction confirmed: block=%d gasUsed=%d", receipt.BlockNumber, receipt.GasUsed)
			}
		}
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
