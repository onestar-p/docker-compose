package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/streadway/amqp"
)

const (
	// 最大重试次数
	MAX_RETRIES = 3

	// RabbitMQ 连接配置
	RABBITMQ_URL = "amqp://admin:rabbitmq123456@localhost:5672/cw_platform_test"

	// 队列配置
	QUEUE_NAME = "your.queue.name"
)

// 业务消息结构
type BusinessMessage struct {
	ID      string      `json:"id"`
	Type    string      `json:"type"`
	Data    interface{} `json:"data"`
	Created time.Time   `json:"created"`
}

func main() {
	// 连接 RabbitMQ
	conn, err := amqp.Dial(RABBITMQ_URL)
	if err != nil {
		log.Fatalf("Failed to connect to RabbitMQ: %v", err)
	}
	defer conn.Close()

	channel, err := conn.Channel()
	if err != nil {
		log.Fatalf("Failed to open channel: %v", err)
	}
	defer channel.Close()

	// 设置 QoS（预取数量）
	err = channel.Qos(
		1,     // prefetch count - 每次只获取1条消息
		0,     // prefetch size
		false, // global
	)
	if err != nil {
		log.Fatalf("Failed to set QoS: %v", err)
	}

	// 声明队列（如果不存在）
	// 注意：策略会自动应用 DLX 等配置
	_, err = channel.QueueDeclare(
		QUEUE_NAME, // name
		true,       // durable
		false,      // delete when unused
		false,      // exclusive
		false,      // no-wait
		nil,        // arguments - 策略会自动应用
	)
	if err != nil {
		log.Fatalf("Failed to declare queue: %v", err)
	}

	// 开始消费
	msgs, err := channel.Consume(
		QUEUE_NAME, // queue
		"",         // consumer
		false,      // auto-ack - 重要！必须手动 ack
		false,      // exclusive
		false,      // no-local
		false,      // no-wait
		nil,        // args
	)
	if err != nil {
		log.Fatalf("Failed to register consumer: %v", err)
	}

	log.Printf("✅ 消费者启动成功，监听队列: %s", QUEUE_NAME)
	log.Printf("⚙️  最大重试次数: %d", MAX_RETRIES)

	// 优雅关闭
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// 处理消息
	go func() {
		for msg := range msgs {
			handleMessage(msg, channel)
		}
	}()

	// 等待退出信号
	<-sigChan
	log.Println("收到退出信号，正在关闭...")
}

// 处理消息（带重试逻辑）
func handleMessage(delivery amqp.Delivery, ch *amqp.Channel) {
	// 获取当前重试次数（从 x-death header）
	retryCount := getRetryCount(delivery)

	log.Printf("📨 收到消息 [重试: %d/%d]", retryCount, MAX_RETRIES)

	// 解析消息
	var msg BusinessMessage
	if err := json.Unmarshal(delivery.Body, &msg); err != nil {
		log.Printf("❌ 消息解析失败: %v, 原始内容: %s", err, string(delivery.Body))
		// 无法解析的消息直接拒绝，不重试
		delivery.Nack(false, false)
		return
	}

	log.Printf("📋 消息内容: ID=%s, Type=%s", msg.ID, msg.Type)

	// 处理业务逻辑
	if err := processBusinessLogic(msg); err != nil {
		log.Printf("❌ 处理失败: %v", err)

		// 判断是否需要重试
		if retryCount < MAX_RETRIES {
			// 还可以重试
			log.Printf("🔄 将重试 (%d/%d)", retryCount+1, MAX_RETRIES)

			// Nack 消息，不重新入队（触发 DLX，进入重试流程）
			delivery.Nack(false, false)
		} else {
			// 超过最大重试次数
			log.Printf("⚠️  超过最大重试次数 (%d)，消息进入死信队列", MAX_RETRIES)

			// 发送告警（可选）
			sendAlert(msg, err)

			// 记录到数据库或日志系统（可选）
			logFailedMessage(msg, err, retryCount)

			// Nack 消息，最终进入死信队列
			delivery.Nack(false, false)
		}
	} else {
		// 处理成功
		log.Printf("✅ 消息处理成功: ID=%s", msg.ID)
		delivery.Ack(false)
	}
}

// 获取重试次数（从 x-death header）
func getRetryCount(delivery amqp.Delivery) int {
	if xDeath, ok := delivery.Headers["x-death"].([]interface{}); ok {
		// x-death 是一个数组，长度就是重试次数
		return len(xDeath)
	}
	return 0
}

// 业务逻辑处理
func processBusinessLogic(msg BusinessMessage) error {
	// 模拟业务处理
	log.Printf("🔧 正在处理业务逻辑...")

	// 这里是你的实际业务逻辑
	// 例如：调用 API、写入数据库、发送通知等

	// 模拟随机失败（测试用）
	// if rand.Intn(2) == 0 {
	//     return fmt.Errorf("模拟业务处理失败")
	// }

	// 模拟处理耗时
	time.Sleep(100 * time.Millisecond)

	return nil
}

// 发送告警（消息最终失败时）
func sendAlert(msg BusinessMessage, err error) {
	log.Printf("🚨 发送告警: 消息处理失败 - ID=%s, Error=%v", msg.ID, err)

	// 实现你的告警逻辑
	// 例如：发送邮件、钉钉、企业微信等
}

// 记录失败消息（用于后续排查）
func logFailedMessage(msg BusinessMessage, err error, retryCount int) {
	log.Printf("📝 记录失败消息: ID=%s, RetryCount=%d, Error=%v", msg.ID, retryCount, err)

	// 实现你的日志记录逻辑
	// 例如：写入数据库、写入文件、发送到日志系统等
}

// 高级用法：自定义重试延迟
func handleMessageWithCustomDelay(delivery amqp.Delivery, ch *amqp.Channel) {
	retryCount := getRetryCount(delivery)

	var msg BusinessMessage
	json.Unmarshal(delivery.Body, &msg)

	if err := processBusinessLogic(msg); err != nil {
		if retryCount < MAX_RETRIES {
			// 计算延迟时间（指数退避）
			delay := calculateRetryDelay(retryCount)
			log.Printf("🔄 将在 %v 后重试 (%d/%d)", delay, retryCount+1, MAX_RETRIES)

			// 发送到延迟队列（需要预先配置延迟队列）
			publishToRetryQueue(ch, msg, delay)

			// 确认原消息
			delivery.Ack(false)
		} else {
			log.Printf("⚠️  超过最大重试次数")
			delivery.Nack(false, false)
		}
	} else {
		delivery.Ack(false)
	}
}

// 计算重试延迟（指数退避）
func calculateRetryDelay(retryCount int) time.Duration {
	// 第1次重试: 30秒
	// 第2次重试: 60秒
	// 第3次重试: 120秒
	baseDelay := 30 * time.Second
	return baseDelay * time.Duration(1<<uint(retryCount))
}

// 发送到延迟重试队列
func publishToRetryQueue(ch *amqp.Channel, msg BusinessMessage, delay time.Duration) error {
	body, _ := json.Marshal(msg)

	return ch.Publish(
		"retry.exchange", // exchange
		"retry.key",      // routing key
		false,            // mandatory
		false,            // immediate
		amqp.Publishing{
			ContentType:  "application/json",
			Body:         body,
			DeliveryMode: amqp.Persistent,
			Expiration:   fmt.Sprintf("%d", delay.Milliseconds()),
		},
	)
}
