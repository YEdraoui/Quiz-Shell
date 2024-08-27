#!/bin/bash

# Shuffle function - uses awk to assign a random number to each line of input,
# sorts the lines by this random number, and then removes the number, effectively shuffling the lines.
shuffle() {
  awk 'BEGIN {srand()} {print rand() "\t" $0}' | sort -k1,1n | cut -f2-
}

# Function to display a question and get the user's answer with limited attempts.
ask_question() {
    attempts=0  # Initialize attempts counter
    max_attempts=3  # Set the maximum number of allowed attempts
    fifty_fifty_used=false  # 50/50 lifeline not used initially
    half_points=false  # Track if 50/50 lifeline was used for scoring

    echo "$question"  # Display the question text

    # Split the answer line into individual answers, shuffle them,
    # and store them in the 'options' array.
    readarray -t options < <(echo $answer_line | tr ';' '\n' | tr ',' '\n' | shuffle)

    # Extract the correct answer from the answer line.
    correct_answer=$(echo $answer_line | cut -d';' -f2)

    # Error handling for malformed answer line
    if [ -z "$correct_answer" ]; then
        echo "Error: The answer line for the current question is malformed."
        exit 1
    fi

    # Display the options for the user
    for i in {0..3}; do
        echo "$((i+1))) ${options[$i]}"
    done

    # Loop until a valid input is received or attempts are exhausted
    while [ $attempts -lt $max_attempts ]; do
        if ! $fifty_fifty_used; then
            read -p "Choose the correct answer (1-4), press '5' to use the 50/50 lifeline, or '6' to skip: " user_choice
        else
            read -p "Choose the correct answer (1-4), or '6' to skip: " user_choice
        fi
        user_choice=$(echo "$user_choice" | xargs)  # Trim leading/trailing whitespace from user input

        # Implement 50/50 lifeline
        if [ "$user_choice" = "5" ] && ! $fifty_fifty_used; then
            fifty_fifty_used=true
            half_points=true  # Activate half points scoring
            correct_index=$(printf "%s\n" "${options[@]}" | grep -nx "$correct_answer" | cut -d':' -f1)
            incorrect_indexes=()
            for i in {1..4}; do
                [ "$i" -ne "$correct_index" ] && incorrect_indexes+=($i)
            done
            readarray -t to_remove < <(echo "${incorrect_indexes[@]}" | tr ' ' '\n' | shuffle | head -n 2)
            for i in {1..4}; do
                if [[ "$i" -eq "$correct_index" ]] || [[ ! "${to_remove[*]}" =~ $i ]]; then
                    echo "$((i))) ${options[$((i-1))]}"
                fi
            done
            continue
        elif [ "$user_choice" = "6" ]; then
            echo "Question skipped."
            return 0  # No points added, question skipped
        fi

        if [ -z "$user_choice" ] || ! [[ "$user_choice" =~ ^[1-6]$ ]]; then
            echo "Invalid input. Please enter a number between 1 and 4, or '5' for the 50/50 lifeline, or '6' to skip."
            continue
        elif [[ $user_choice =~ ^[1-4]$ ]]; then
            attempts=$((attempts + 1))  # Increment attempts only on valid input
            if [ "${options[$((user_choice-1))]}" = "$correct_answer" ]; then
                echo "Correct! You took $attempts attempts."
                return 1  # Return 1 for a correct answer
            else
                echo "Incorrect! Please try again."
                remaining_attempts=$((max_attempts - attempts))
                if [ $remaining_attempts -gt 0 ]; then
                    echo "You have $remaining_attempts attempts left."
                else
                    echo "No attempts left."
                    echo "The correct answer was: $correct_answer"
                    return 0  # Return 0 for an incorrect answer after max attempts
                fi
            fi
        fi
    done
}

# Initialize score to 0
score=0

# Verify necessary files are present and not empty
if [ ! -s questions.txt ] || [ ! -s answers.txt ]; then
    echo "Error: questions.txt and/or answers.txt files are missing or empty."
    exit 1
fi

# Load questions and answers into arrays
readarray -t questions < questions.txt
readarray -t answers < answers.txt

# Main game loop
while true; do
    # Shuffle questions and answers
    readarray -t shuffled_questions < <(printf "%s\n" "${questions[@]}" | shuffle)
    readarray -t shuffled_answers < <(printf "%s\n" "${answers[@]}" | shuffle)

    # Loop through each shuffled question and answer pair
    for i in "${!shuffled_questions[@]}"; do
        question="${shuffled_questions[$i]}"
        answer_line="${shuffled_answers[$i]}"
        ask_question
        correct=$?

        # Update score based on correctness
        if [ $correct -eq 1 ]; then
            point_value=(2 10 20 50 100)  # Multiply point values by 2
            if [ "$half_points" = true ]; then
                score=$((score + point_value[i % 5] / 2))  # Use integer division to divide score by 2
            else
                score=$((score + point_value[i % 5]))
            fi
        fi

        echo "Current Score: $score"

        # Prompt to continue or end the game
        while true; do
            read -p "Continue? (yes/no): " cont
            cont=$(echo "$cont" | xargs | tr '[:upper:]' '[:lower:]')

            if [ -z "$cont" ]; then
                echo "Please type 'yes' or 'no'."
            elif [ "$cont" = "yes" ]; then
                break
            elif [ "$cont" = "no" ]; then
                echo "Final Score: $score"
                exit 0
            else
                echo "Invalid input. Please type 'yes' to continue or 'no' to exit."
            fi
        done
    done
done
